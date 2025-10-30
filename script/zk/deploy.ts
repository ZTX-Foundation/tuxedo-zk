#!/usr/bin/env node

import { intro, outro, select, confirm, spinner } from "@clack/prompts";
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
    "localnet-zk": {
        name: "Local Network ZK",
        rpcUrl: "http://127.0.0.1:8011",
        chainId: 260,
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

    // Validate DEPLOYER_PRIVATE_KEY
    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;

    if (!privateKey) {
        outro("❌ DEPLOYER_PRIVATE_KEY not found in environment variables");
        process.exit(1);
    }

    if (!privateKey.startsWith("0x") || privateKey.length !== 66) {
        outro("❌ Invalid DEPLOYER_PRIVATE_KEY format in .env file");
        process.exit(1);
    }

    // Build command arguments with broadcast enabled
    const baseArgs = [
        "--rpc-url",
        networkConfig.rpcUrl,
        "--zksync",
        "-vvvv",
        "--broadcast",
        "--private-key",
        privateKey,
    ];

    // Summary
    console.log("\n📋 Deployment Summary:");
    console.log(`  Network: ${networkConfig.name}`);
    console.log(`  Chain ID: ${networkConfig.chainId}`);
    console.log(`  RPC URL: ${networkConfig.rpcUrl}`);
    console.log(`  Run ID: ${runManager.getRunId()}`);
    console.log(
        `  Proposals: ${proposalsToDeploy.length} (starting from ${proposalsToDeploy[0]})`
    );
    console.log(`  Mode: Broadcasting live`);
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
                },
            });

            s.stop(`✅ ${proposal} deploy() completed`);

            // Check if this proposal has governance actions
            if (PROPOSALS_WITH_BUILD.includes(proposal)) {
                console.log(
                    `\n📋 ${proposal} has governance actions that need to be submitted\n`
                );
                console.log(
                    `Please scroll up to find the "Schedule Calldata" and "Execute Calldata" sections.`
                );
                console.log(
                    `Copy those transactions and submit them via the multisig to the TimelockController.\n`
                );

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
