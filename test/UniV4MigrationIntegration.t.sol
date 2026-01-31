// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {
    IUniswapCCAMigrationHelper
} from "../src/interfaces/IUniswapCCAMigrationHelper.sol";

// Uniswap v4 imports for minting position
import {
    IPositionManager
} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {
    IPermit2
} from "@uniswap/v4-periphery/lib/permit2/src/interfaces/IPermit2.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract UniV4MigrationIntegrationTest is Test {
    // === Base Token Addresses ===
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // === Uniswap v4 on Base ===
    address constant POSITION_MANAGER =
        0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // === UniV4 Migration Helper on Base ===
    address constant UNIV4_MIGRATION_HELPER =
        0xb4120Bf580C2c386D11435a30664ceA239E09c5c;
    address constant UNIV4_MIGRATION_OWNER =
        0x25CF23B54e25daaE3fe9989a74050b953A343823;

    // === Arrakis on Base ===
    address constant ARRAKIS_FACTORY =
        0x820FB8127a689327C863de8433278d6181123982;
    address constant UNIV4_PRIVATE_BEACON =
        0x97d42db1B71B1c9a811a73ce3505Ac00f9f6e5fB;
    address constant BUNKER_MODULE_BEACON =
        0x3025b46A9814a69EAf8699EDf905784Ee22C3ABB;

    IUniswapCCAMigrationHelper migrationHelper;
    uint256 positionTokenId;
    PoolKey poolKey;
    address user;

    function setUp() public {
        // Fork Base
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        user = makeAddr("user");
        migrationHelper = IUniswapCCAMigrationHelper(UNIV4_MIGRATION_HELPER);

        // Setup pool key for WETH/USDC
        // On Base: WETH (0x420000...) < USDC (0x833589...) when sorted by address
        poolKey = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(USDC),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Setup: Mint a Uniswap v4 position
        _mintPosition();

        // Whitelist hook (if any) using owner
        address hook = address(poolKey.hooks);
        if (hook != address(0)) {
            vm.prank(UNIV4_MIGRATION_OWNER);
            migrationHelper.addApprovedHook(hook);
        }
    }

    function test_migration() public {
        console.log("=== UniV4 Migration Integration Test ===");
        console.log("Position Token ID:", positionTokenId);

        // Build migration params
        IUniswapCCAMigrationHelper.MigrationParams memory params =
            _buildMigrationParams();

        // Execute migration
        vm.startPrank(user);

        uint256[] memory positionTokenIds = new uint256[](1);
        positionTokenIds[0] = positionTokenId;

        IERC721(POSITION_MANAGER)
            .approve(address(migrationHelper), positionTokenId);

        address vault =
            migrationHelper.migratePositions(positionTokenIds, params);

        vm.stopPrank();

        // Minimal verification
        assertTrue(vault != address(0), "Vault should be created");
        console.log("Migration successful!");
        console.log("Vault address:", vault);
    }

    function _mintPosition() internal {
        console.log("=== Starting _mintPosition ===");

        // Deal tokens to user before prank
        console.log("Dealing USDC...");
        deal(USDC, user, 2000e6, true);
        console.log("USDC balance:", IERC20(USDC).balanceOf(user));

        // For WETH, we need to deal ETH and wrap it
        console.log("Dealing ETH and wrapping to WETH...");
        vm.deal(user, 2 ether);
        vm.prank(user);
        (bool success,) = WETH.call{value: 1 ether}("");
        require(success, "WETH wrap failed");
        console.log("WETH balance:", IERC20(WETH).balanceOf(user));

        vm.startPrank(user);

        // Initialize the pool if it doesn't exist
        console.log("Initializing pool...");
        int24 initialTick = -200000;
        initialTick = initialTick - (initialTick % poolKey.tickSpacing);
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(initialTick);
        int24 result = IPositionManager(POSITION_MANAGER)
            .initializePool(poolKey, sqrtPriceX96);
        console.log("Pool initialization result (tick or max):", result);

        // Approve tokens to Permit2
        console.log("Approving tokens to Permit2...");
        IERC20(WETH).approve(PERMIT2, type(uint256).max);
        IERC20(USDC).approve(PERMIT2, type(uint256).max);

        // Approve Permit2 to spend on behalf of PositionManager
        console.log("Setting Permit2 approvals for PositionManager...");
        IPermit2(PERMIT2)
            .approve(
                WETH, POSITION_MANAGER, type(uint160).max, type(uint48).max
            );
        IPermit2(PERMIT2)
            .approve(
                USDC, POSITION_MANAGER, type(uint160).max, type(uint48).max
            );

        // Get the next token ID before minting
        positionTokenId = IPositionManager(POSITION_MANAGER).nextTokenId();
        console.log("Next token ID:", positionTokenId);

        // Calculate tick bounds around the initial tick
        int24 tickSpacing = poolKey.tickSpacing;
        int24 tickLower = initialTick - tickSpacing * 50;
        int24 tickUpper = initialTick + tickSpacing * 50;

        // Use a small liquidity amount for testing
        uint128 liquidity = 1e12;

        console.log("Minting position...");
        console.log("Tick lower:", tickLower);
        console.log("Tick upper:", tickUpper);

        // Encode mint action
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR)
        );

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            poolKey,
            tickLower,
            tickUpper,
            liquidity,
            type(uint256).max, // maxAmount0
            type(uint256).max, // maxAmount1
            user, // owner
            bytes("") // hookData
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        IPositionManager(POSITION_MANAGER)
            .modifyLiquidities(abi.encode(actions, params), type(uint256).max);

        vm.stopPrank();

        console.log("Minted position with token ID:", positionTokenId);
    }

    function _buildMigrationParams()
        internal
        view
        returns (IUniswapCCAMigrationHelper.MigrationParams memory)
    {
        // Precompute vault address using Create3
        // The factory computes salt as: keccak256(abi.encode(msg.sender, salt_))
        // where msg.sender is the migration helper (caller of deployPrivateVault)
        bytes32 userSalt = keccak256(abi.encode("test-migration"));
        bytes32 factorySalt =
            keccak256(abi.encode(address(migrationHelper), userSalt));
        address precomputedVault =
            _computeCreate3Address(ARRAKIS_FACTORY, factorySalt);

        // Build Bunker module payload with precomputed vault address
        IUniswapCCAMigrationHelper.ModuleToWhitelist[] memory
            additionalModules =
            new IUniswapCCAMigrationHelper.ModuleToWhitelist[](1);
        additionalModules[0] = IUniswapCCAMigrationHelper.ModuleToWhitelist({
            beacon: BUNKER_MODULE_BEACON,
            payload: abi.encodeWithSignature(
                "initialize(address)", precomputedVault
            )
        });

        return IUniswapCCAMigrationHelper.MigrationParams({
            vaultCreation: IUniswapCCAMigrationHelper.VaultCreation({
                salt: userSalt,
                upgradeableBeacon: UNIV4_PRIVATE_BEACON,
                maxDeviation: 200, // 2%
                cooldownPeriod: 60, // 60 seconds
                stratAnnouncer: address(0),
                maxSlippage: 500, // 5%
                additionalModulesToWhitelist: additionalModules
            }),
            executor: user
        });
    }

    /// @notice Compute the Create3 deployed address for a given deployer and salt
    function _computeCreate3Address(
        address deployer,
        bytes32 salt
    ) internal pure returns (address) {
        // Create3 proxy address via CREATE2
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            keccak256(hex"67363d3d37363d34f03d5260086018f3")
                        )
                    )
                )
            )
        );

        // Final contract address via CREATE (nonce=1) from the proxy
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)
                        )
                    )
                )
            )
        );
    }
}
