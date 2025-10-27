// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @notice Mock contract to store and retrieve environment variables
/// @dev Use this in zkSync deployments where vm.envOr() doesn't work in constructors
contract EnvMock {
    mapping(string key => bool) private boolValues;
    mapping(string key => uint256) private uint256Values;
    mapping(string key => string) private stringValues;
    mapping(string key => bool) private boolExists;
    mapping(string key => bool) private uint256Exists;
    mapping(string key => bool) private stringExists;

    /// @notice Store a bool environment variable
    function storeBool(string calldata name, bool value) external {
        boolValues[name] = value;
        boolExists[name] = true;
    }

    /// @notice Store a uint256 environment variable
    function storeUint256(string calldata name, uint256 value) external {
        uint256Values[name] = value;
        uint256Exists[name] = true;
    }

    /// @notice Store a string environment variable
    function storeString(string calldata name, string calldata value) external {
        stringValues[name] = value;
        stringExists[name] = true;
    }

    /// @notice Gets the environment variable `name` and parses it as `bool`.
    /// Returns `defaultValue` if the variable was not found.
    function envOr(string calldata name, bool defaultValue) external view returns (bool value) {
        if (boolExists[name]) {
            return boolValues[name];
        }
        return defaultValue;
    }

    /// @notice Gets the environment variable `name` and parses it as `uint256`.
    /// Returns `defaultValue` if the variable was not found.
    function envOr(string calldata name, uint256 defaultValue) external view returns (uint256 value) {
        if (uint256Exists[name]) {
            return uint256Values[name];
        }
        return defaultValue;
    }

    /// @notice Gets the environment variable `name` and parses it as `string`.
    /// Returns `defaultValue` if the variable was not found.
    function envOr(string calldata name, string calldata defaultValue) external view returns (string memory value) {
        if (stringExists[name]) {
            return stringValues[name];
        }
        return defaultValue;
    }

    /// @notice Gets the environment variable `name` as `string`.
    /// Reverts if the variable was not found.
    function envString(string calldata name) external view returns (string memory value) {
        require(stringExists[name], "EnvMock: string variable not found");
        return stringValues[name];
    }
}
