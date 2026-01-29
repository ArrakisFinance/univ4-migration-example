// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IUniswapCCAMigrationHelper {
    // #region structs.

    /// @notice Parameters for creating the new Arrakis vault
    struct VaultCreation {
        bytes32 salt;
        address upgradeableBeacon;
        uint24 maxDeviation;
        uint256 cooldownPeriod;
        address stratAnnouncer;
        uint24 maxSlippage;
    }

    /// @notice Parameters for the migration
    /// @dev Supports migrating multiple position NFTs (e.g., full range + one-sided limit order)
    /// @dev Rebalance payloads are auto-generated from extracted position data
    struct MigrationParams {
        VaultCreation vaultCreation;
        address executor;
    }

    /// @notice Internal state for a single position range
    struct PositionRange {
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;
    }

    /// @notice Internal state struct for migration
    /// @dev Supports multiple position ranges from multiple NFTs
    struct MigrationState {
        address token0;
        address token1;
        uint256 totalAmount0; // Total across all positions
        uint256 totalAmount1; // Total across all positions
        PositionRange[] ranges; // Array of ranges from all positions
        PoolKey poolKey;
        address hook;
        bool isInversed;
    }

    // #endregion structs.

    // #region events.

    /// @notice Emitted when position(s) are successfully migrated
    /// @param positionTokenIds The original Uniswap v4 position NFT token IDs (can be multiple)
    /// @param vault The address of the newly created Arrakis vault
    /// @param owner The address of the vault owner (original position owner)
    /// @param executor The address of the vault executor
    /// @param amount0 The total amount of token0 migrated across all positions
    /// @param amount1 The total amount of token1 migrated across all positions
    /// @param rangeCount The number of tick ranges migrated
    event PositionMigrated(
        uint256[] positionTokenIds,
        address indexed vault,
        address indexed owner,
        address executor,
        uint256 amount0,
        uint256 amount1,
        uint256 rangeCount
    );

    /// @notice Emitted when a hook is approved for migration
    /// @param hook The hook address that was approved
    event HookApproved(address indexed hook);

    /// @notice Emitted when a hook is removed from the approved list
    /// @param hook The hook address that was removed
    event HookRemoved(address indexed hook);

    // #endregion events.

    // #region errors.

    /// @notice Error emitted when an address parameter is zero
    error AddressZero();

    /// @notice Error emitted when extracting liquidity from position fails
    error LiquidityExtractionFailed();

    /// @notice Error emitted when vault creation fails
    error VaultCreationFailed();

    /// @notice Error emitted when deposit fails
    error DepositFailed();

    /// @notice Error emitted when rebalance fails
    error RebalanceFailed();

    /// @notice Error emitted when updating executor fails
    error ExecutorUpdateFailed();

    /// @notice Error emitted when no liquidity is extracted from position
    error NoLiquidityExtracted();

    /// @notice Error emitted when no position token IDs are provided
    error NoPositionTokenIds();

    /// @notice Error emitted when positions have different pool keys
    /// @param tokenId The token ID with mismatched pool
    /// @param expectedPoolId The expected pool ID
    /// @param actualPoolId The actual pool ID
    error PoolKeyMismatch(
        uint256 tokenId, bytes25 expectedPoolId, bytes25 actualPoolId
    );

    /// @notice Error emitted when extracted tokens don't match pool currencies
    /// @param token0 The first token address
    /// @param token1 The second token address
    /// @param currency0 The pool's currency0 address
    /// @param currency1 The pool's currency1 address
    error TokenMismatch(
        address token0, address token1, address currency0, address currency1
    );

    /// @notice Error emitted when a hook is not approved for migration
    /// @param hook The hook address that is not approved
    error HookNotApproved(address hook);

    // #endregion errors.

    // #region functions.

    /// @notice Migrate Uniswap v4 CCA/LBP position(s) to an Arrakis Pro vault
    /// @dev Caller must be the owner of all position NFTs and must have approved this contract
    /// @dev Supports migrating multiple positions (e.g., full range + one-sided limit order from LBP)
    /// @dev All positions must be from the same pool (same pool key)
    /// @param positionTokenIds_ Array of token IDs of the Uniswap v4 position NFTs to migrate
    /// @param params_ Migration parameters including vault creation and rebalance settings
    /// @return vault The address of the newly created Arrakis vault
    function migratePositions(
        uint256[] calldata positionTokenIds_,
        MigrationParams calldata params_
    ) external returns (address vault);

    // #endregion functions.

    // #region view functions.

    /// @notice Get the address of the Uniswap v4 Position Manager
    function positionManager() external view returns (address);

    /// @notice Get the address of the Uniswap v4 Pool Manager
    function poolManager() external view returns (address);

    /// @notice Get the address of the Arrakis Meta Vault Factory
    function factory() external view returns (address);

    /// @notice Get the address of the Arrakis Standard Manager
    function manager() external view returns (address);

    /// @notice Get the address of the Private Vault NFT contract
    function vaultNFT() external view returns (address);

    // #endregion view functions.

    // #region governance functions.

    /// @notice Add a hook to the approved list
    /// @param hook_ The hook address to approve
    function addApprovedHook(
        address hook_
    ) external;

    /// @notice Remove a hook from the approved list
    /// @param hook_ The hook address to remove
    function removeApprovedHook(
        address hook_
    ) external;

    // #endregion governance functions.
}
