import * as fs from "fs";
import * as path from "path";
import { format } from "date-fns";
import { DeployedAddress, DeploymentRun, LatestRun } from "./types";

export class RunManager {
    private chainId: number;
    private runId: string;
    private runDir: string;
    private runFilePath: string;

    constructor(chainId: number, runId?: string) {
        this.chainId = chainId;
        this.runDir = path.join("deployments", chainId.toString());

        // Ensure run directory exists
        if (!fs.existsSync(this.runDir)) {
            fs.mkdirSync(this.runDir, { recursive: true });
        }

        if (runId) {
            // Resume existing run
            this.runId = runId;
            this.runFilePath = path.join(
                this.runDir,
                `deployment-${runId}.json`
            );

            if (!fs.existsSync(this.runFilePath)) {
                throw new Error(`Run file not found: ${this.runFilePath}`);
            }
        } else {
            // Create new run
            this.runId = Date.now().toString();
            this.runFilePath = path.join(
                this.runDir,
                `deployment-${this.runId}.json`
            );
            this.initializeRun();
        }
    }

    private initializeRun() {
        const run: DeploymentRun = {
            createdAt: parseInt(this.runId),
            lastCompletedProposal: -1, // None completed yet
            deployedAddresses: [],
        };

        fs.writeFileSync(
            this.runFilePath,
            JSON.stringify(run, null, 2),
            "utf-8"
        );

        this.updateLatestRun();
    }

    private updateLatestRun() {
        const latestRunPath = path.join(this.runDir, "deployment-latest.json");
        const latestRun: LatestRun = {
            runId: this.runId,
        };
        fs.writeFileSync(
            latestRunPath,
            JSON.stringify(latestRun, null, 2),
            "utf-8"
        );
    }

    private readRun(): DeploymentRun {
        return JSON.parse(fs.readFileSync(this.runFilePath, "utf-8"));
    }

    getNextProposalIndex(): number {
        const run = this.readRun();
        return run.lastCompletedProposal + 1;
    }

    markProposalCompleted(proposalIndex: number) {
        // Read current state from file
        const run = this.readRun();

        // Update only the lastCompletedProposal field
        run.lastCompletedProposal = proposalIndex;

        // Write back to file
        fs.writeFileSync(
            this.runFilePath,
            JSON.stringify(run, null, 2),
            "utf-8"
        );
    }

    getRunId(): string {
        return this.runId;
    }

    getRunFilePath(): string {
        return path.resolve(this.runFilePath);
    }

    static listRuns(chainId: number): Array<{
        runId: string;
        createdAt: number;
        formattedDate: string;
        lastCompletedProposal: number;
    }> {
        const runDir = path.join("deployments", chainId.toString());

        if (!fs.existsSync(runDir)) {
            return [];
        }

        const files = fs
            .readdirSync(runDir)
            .filter(
                (file) =>
                    file.startsWith("deployment-") &&
                    file.endsWith(".json") &&
                    file !== "deployment-latest.json"
            );

        const runs = files.map((file) => {
            const runId = file.replace("deployment-", "").replace(".json", "");
            const runData: DeploymentRun = JSON.parse(
                fs.readFileSync(path.join(runDir, file), "utf-8")
            );

            return {
                runId,
                createdAt: runData.createdAt,
                formattedDate: format(
                    new Date(runData.createdAt),
                    "HH:mm MM/dd/yyyy"
                ),
                lastCompletedProposal: runData.lastCompletedProposal,
            };
        });

        // Sort by creation date descending (newest first)
        return runs.sort((a, b) => b.createdAt - a.createdAt);
    }

    static getLatestRunId(chainId: number): string | null {
        const latestRunPath = path.join(
            "deployments",
            chainId.toString(),
            "deployment-latest.json"
        );

        if (!fs.existsSync(latestRunPath)) {
            return null;
        }

        const latestRun: LatestRun = JSON.parse(
            fs.readFileSync(latestRunPath, "utf-8")
        );
        return latestRun.runId;
    }
}
