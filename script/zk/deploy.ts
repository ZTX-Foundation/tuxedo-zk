#!/usr/bin/env node

import { intro, outro, select, text, confirm, spinner } from "@clack/prompts";
import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";
import { RunManager } from "./RunManager";

// Load environment variables from .env file
dotenv.config();

// Handle Ctrl+C gracefully
process.on("SIGINT", () => {
    console.log("\n\n👋 Deployment interrupted by user");
    process.exit(130); // Standard exit code for SIGINT
});

// Network configuration with chain IDs
const NETWORKS = {
    "creator-testnet": {
        name: "Creator Testnet",
        rpcUrl: "https://creator-testnet.rpc.caldera.xyz/http",
        chainId: 4654,
    },
    localnet: {
        name: "Local Network",
        rpcUrl: "http://127.0.0.1:8545",
        chainId: 31337,
    },
    mainnet: {
        name: "Mainnet",
        rpcUrl: "https://arb1.arbitrum.io/rpc",
        chainId: 42161,
    },
    qa: {
        name: "QA Network",
        rpcUrl: "https://qa.rpc.caldera.xyz/http",
        chainId: 99999, // Update with actual chain ID
    },
} as const;

type NetworkKey = keyof typeof NETWORKS;

// Get available proposals
const PROPOSALS_DIR = "proposals/zips";
const availableProposals = fs
    .readdirSync(PROPOSALS_DIR)
    .filter((file) => /^zip\d{3}\.sol$/.test(file))
    .map((file) => file.replace(".sol", ""))
    .sort();

// Proposals with build() functions that require governance submission
const PROPOSALS_WITH_BUILD = [
    "zip003",
    "zip004",
    "zip005",
    "zip006",
    "zip007",
    "zip008",
    "zip009",
    "zip010",
    "zip011",
    "zip012",
    "zip013",
    "zip014",
    "zip016",
    "zip017",
    "zip018",
    "zip019",
    "zip020",
    "zip021",
];

async function main() {
    console.clear();

    intro("🚀 ZTX Contract Deployment");

    // Step 1: Select network
    const network = (await select({
        message: "Select network",
        options: Object.entries(NETWORKS).map(([key, config]) => ({
            value: key,
            label: config.name,
            hint: config.rpcUrl,
        })),
    })) as NetworkKey;

    if (!network) {
        outro("Deployment cancelled");
        process.exit(0);
    }

    const networkConfig = NETWORKS[network];

    // Step 2: Resume or new run
    const runChoice = await select({
        message: "Do you want to resume a run or start a new one?",
        options: [
            { value: "new", label: "New run" },
            { value: "resume", label: "Resume run" },
        ],
    });

    if (!runChoice) {
        outro("Deployment cancelled");
        process.exit(0);
    }

    let runManager: RunManager;
    let startProposalIndex = 0;

    if (runChoice === "resume") {
        const runs = RunManager.listRuns(networkConfig.chainId);

        if (runs.length === 0) {
            outro("No runs found for this network. Please start a new run.");
            process.exit(0);
        }

        const selectedRunId = await select({
            message: "Select a run to resume",
            options: runs.map((run) => ({
                value: run.runId,
                label: `${run.formattedDate} - Last completed: zip${run.lastCompletedProposal.toString().padStart(3, "0")}`,
                hint: `${run.lastCompletedProposal + 1} proposals completed`,
            })),
        });

        if (!selectedRunId) {
            outro("Deployment cancelled");
            process.exit(0);
        }

        runManager = new RunManager(
            networkConfig.chainId,
            selectedRunId as string
        );
        startProposalIndex = runManager.getNextProposalIndex();

        console.log(
            `\nResuming from proposal index ${startProposalIndex} (${availableProposals[startProposalIndex]})`
        );
    } else {
        runManager = new RunManager(networkConfig.chainId);
        console.log(`\nCreated new run: ${runManager.getRunId()}`);
    }

    const proposalsToDeploy = availableProposals.slice(startProposalIndex);

    // Step 3: Broadcast or simulate
    const mode = await select({
        message: "Deploy mode",
        options: [
            {
                value: "simulate",
                label: "Simulate (dry run)",
                hint: "Test without broadcasting transactions",
            },
            {
                value: "broadcast",
                label: "Broadcast (live deployment)",
                hint: "Deploy to network using DEPLOYER_PRIVATE_KEY from .env",
            },
        ],
    });

    if (!mode) {
        outro("Deployment cancelled");
        process.exit(0);
    }

    // Build command arguments
    const baseArgs = ["--rpc-url", networkConfig.rpcUrl, "--zksync", "-vvvv"];

    if (mode === "broadcast") {
        const privateKey = process.env.DEPLOYER_PRIVATE_KEY;

        if (!privateKey) {
            outro("❌ DEPLOYER_PRIVATE_KEY not found in environment variables");
            process.exit(1);
        }

        if (!privateKey.startsWith("0x") || privateKey.length !== 66) {
            outro("❌ Invalid DEPLOYER_PRIVATE_KEY format in .env file");
            process.exit(1);
        }

        baseArgs.push("--broadcast", "--private-key", privateKey);
    }

    // Summary
    console.log("\n📋 Deployment Summary:");
    console.log(`  Network: ${networkConfig.name}`);
    console.log(`  Chain ID: ${networkConfig.chainId}`);
    console.log(`  RPC URL: ${networkConfig.rpcUrl}`);
    console.log(`  Run ID: ${runManager.getRunId()}`);
    console.log(
        `  Proposals: ${proposalsToDeploy.length} (starting from ${proposalsToDeploy[0]})`
    );
    console.log(
        `  Mode: ${mode === "broadcast" ? "🔴 BROADCAST (live)" : "🟡 SIMULATE (dry run)"}`
    );
    console.log("");

    const proceed = await confirm({
        message: "Proceed with deployment?",
    });

    if (!proceed) {
        outro("Deployment cancelled");
        process.exit(0);
    }

    // Execute deployments
    const s = spinner();

    for (let i = 0; i < proposalsToDeploy.length; i++) {
        const proposal = proposalsToDeploy[i];
        const proposalIndex = startProposalIndex + i;
        const proposalPath = path.join(PROPOSALS_DIR, `${proposal}.sol`);

        s.start(`Deploying ${proposal} (${i + 1}/${proposalsToDeploy.length})`);

        try {
            const command = ["forge", "script", proposalPath, ...baseArgs].join(
                " "
            );

            console.log(`\n$ ${command}\n`);

            execSync(command, {
                stdio: "inherit",
                cwd: process.cwd(),
                env: {
                    ...process.env,
                    RUN_ID: runManager.getRunId(),
                    RUN_FILE_PATH: runManager.getRunFilePath(),
                    ENVIRONMENT: network,
                    DO_BUILD: "false", // Only run deploy(), not build()
                    DO_SIMULATE: "false",
                },
            });

            s.stop(`✅ ${proposal} deploy() completed`);

            // Check if this proposal has governance actions
            if (PROPOSALS_WITH_BUILD.includes(proposal)) {
                console.log(
                    `\n📋 ${proposal} has governance actions that need to be submitted\n`
                );

                // Run build to generate calldata
                s.start(`Generating governance calldata for ${proposal}`);

                const buildCommand = [
                    "forge",
                    "script",
                    proposalPath,
                    "--rpc-url",
                    networkConfig.rpcUrl,
                    "--zksync",
                ].join(" ");

                try {
                    const calldataOutput = execSync(buildCommand, {
                        cwd: process.cwd(),
                        env: {
                            ...process.env,
                            RUN_ID: runManager.getRunId(),
                            RUN_FILE_PATH: runManager.getRunFilePath(),
                            ENVIRONMENT: network,
                            DO_DEPLOY: "false", // Don't deploy again
                            DO_BUILD: "true", // Generate actions
                            DO_SIMULATE: "false",
                            DO_VALIDATE: "false",
                            DO_PRINT: "true", // Print calldata
                        },
                        encoding: "utf-8",
                    });

                    s.stop(`Calldata generated for ${proposal}`);

                    // Display calldata
                    console.log("\n" + "=".repeat(80));
                    console.log("📝 GOVERNANCE CALLDATA OUTPUT:");
                    console.log("=".repeat(80));
                    console.log(calldataOutput);
                    console.log("=".repeat(80) + "\n");
                } catch (buildError) {
                    s.stop(`⚠️  Failed to generate calldata for ${proposal}`);
                    console.warn(
                        "Could not generate calldata, but deploy() succeeded"
                    );
                }

                // Pause for user to submit governance actions
                console.log(
                    `\n⏸️  Please submit the above governance calldata to the TimelockController:`
                );
                console.log(`   1. Copy the "Schedule Calldata" from above`);
                console.log(
                    `   2. Call scheduleBatch() on TimelockController from ADMIN_MULTISIG`
                );
                console.log(`   3. Wait for delay period (if any)`);
                console.log(
                    `   4. Call executeBatch() on TimelockController from ADMIN_MULTISIG`
                );
                console.log("");

                const governanceSubmitted = await confirm({
                    message: `Have you submitted and executed the governance actions for ${proposal}?`,
                });

                if (!governanceSubmitted) {
                    console.log(
                        `\n⚠️  Deployment paused. You can resume this deployment later.`
                    );
                    console.log(
                        `   When ready, run the deploy script again and select "Resume run"\n`
                    );
                    outro("Deployment paused for governance submission");
                    process.exit(0);
                }
            }

            // Mark proposal as completed
            runManager.markProposalCompleted(proposalIndex);
        } catch (error) {
            s.stop(`❌ ${proposal} deployment failed`);
            console.error(`Error deploying ${proposal}:`, error);

            const continueOnError = await confirm({
                message: "Continue with remaining proposals?",
            });

            if (!continueOnError) {
                outro("Deployment stopped");
                process.exit(1);
            }
        }
    }

    outro("🎉 Deployment complete!");
}

main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
