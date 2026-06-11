// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script} from "forge-std/Script.sol";
import {NftMarket} from "../src/NftMarket.sol";

contract DeployNftMarket is Script {
    function run() external returns (NftMarket) {
        // Platform fees: 250 basis points = 2.5%
        uint256 platformFees = 250;
        // Marketplace owner address (deployer address)
        address marketplaceOwner = msg.sender;

        vm.startBroadcast();

        NftMarket nftMarket = new NftMarket(platformFees, marketplaceOwner);

        vm.stopBroadcast();

        return nftMarket;
    }
}
