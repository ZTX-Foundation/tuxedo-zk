export interface DeployedAddress {
    addr: string;
    name: string;
    chainId: number;
    isContract: boolean;
}

export interface DeploymentRun {
    createdAt: number;
    lastCompletedProposal: number; // 0-21, -1 means none completed yet
    deployedAddresses: DeployedAddress[];
}

export interface LatestRun {
    runId: string;
}
