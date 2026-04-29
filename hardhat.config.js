import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [hardhatToolboxMochaEthersPlugin],
  
  solidity: "0.8.28",
  
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545", 
      chainId: 1337,                
    }
  }
});