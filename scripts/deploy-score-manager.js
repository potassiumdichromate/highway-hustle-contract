// scripts/deploy-score-manager.js (ESM VERSION)
import hre from "hardhat";
import readline from "readline";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
  console.log("🚨 ========== MAINNET DEPLOYMENT WARNING ========== 🚨\n");
  console.log("⚠️  You are about to deploy ScoreManager to 0G MAINNET!");
  console.log("⚠️  This will use REAL 0G tokens for deployment!");
  console.log("⚠️  Make sure you have:");
  console.log("    1. Funded your deployer wallet with real 0G tokens");
  console.log("    2. Tested the contract on testnet first");
  console.log("    3. Backed up your private key securely");
  console.log("    4. Double-checked the contract code\n");

  const confirm = await question("Type 'DEPLOY' to continue or anything else to cancel: ");
  
  if (confirm !== 'DEPLOY') {
    console.log("\n❌ Deployment cancelled. Safety first!");
    rl.close();
    process.exit(0);
  }

  console.log("\n🚀 Starting MAINNET deployment...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("👛 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  const balanceInEther = hre.ethers.formatEther(balance);
  console.log("💰 Account balance:", balanceInEther, "0G");

  // Safety check
  if (parseFloat(balanceInEther) < 10) {
    console.log("\n⚠️  WARNING: Low balance! Recommended minimum: 10 0G");
    const proceedLow = await question("Continue anyway? (yes/no): ");
    if (proceedLow.toLowerCase() !== 'yes') {
      console.log("\n❌ Deployment cancelled. Please fund your wallet first.");
      rl.close();
      process.exit(0);
    }
  }

  console.log("\n🎯 Deploying ScoreManager contract...");
  
  // Get contract factory
  const ScoreManager = await hre.ethers.getContractFactory("ScoreManager");
  
  // Estimate deployment cost
  try {
    const deploymentData = ScoreManager.getDeployTransaction();
    const gasEstimate = await hre.ethers.provider.estimateGas({
      data: deploymentData.data
    });
    const feeData = await hre.ethers.provider.getFeeData();
    const estimatedCost = gasEstimate * feeData.gasPrice;
    
    console.log("⛽ Estimated deployment cost:", hre.ethers.formatEther(estimatedCost), "0G");
    console.log("⛽ Estimated gas:", gasEstimate.toString());
  } catch (e) {
    console.log("⚠️  Could not estimate gas, proceeding anyway...");
  }

  const deployConfirm = await question("\nProceed with deployment? (yes/no): ");
  if (deployConfirm.toLowerCase() !== 'yes') {
    console.log("\n❌ Deployment cancelled.");
    rl.close();
    process.exit(0);
  }

  console.log("\n📤 Sending deployment transaction...");
  const contract = await ScoreManager.deploy();

  console.log("⏳ Waiting for deployment confirmation...");
  await contract.waitForDeployment();
  
  const contractAddress = await contract.getAddress();

  console.log("\n✅ ========== DEPLOYMENT SUCCESSFUL! ========== ✅\n");
  console.log("🎯 Contract Address:", contractAddress);
  console.log("\n📋 CRITICAL: Add this to your backend .env file:");
  console.log("─────────────────────────────────────────────────");
  console.log(`SCORE_CONTRACT_ADDRESS=${contractAddress}`);
  console.log("─────────────────────────────────────────────────");
  
  console.log("\n🔗 View on 0G Mainnet Block Explorer:");
  console.log(`https://scan.0g.ai/address/${contractAddress}`);

  // Verify initial state
  console.log("\n🔍 Verifying deployment...");
  const stats = await contract.getStats();
  console.log("📊 Initial Contract Stats:");
  console.log("   ✓ Total Submissions:", stats[0].toString());
  console.log("   ✓ Total Players:", stats[1].toString());
  console.log("   ✓ Total Snapshots:", stats[2].toString());
  console.log("   ✓ Owner:", stats[3]);

  console.log("\n🎮 Game Modes Supported:");
  console.log("   0. OneWay");
  console.log("   1. TwoWay");
  console.log("   2. TimeAttack");
  console.log("   3. Bomb");

  console.log("\n🛡️ Anti-Cheat Features:");
  console.log("   ✓ Minimum 30s between submissions");
  console.log("   ✓ Maximum score validation");
  console.log("   ✓ Score verification system");
  console.log("   ✓ Timestamp tracking");

  // Post-deployment checklist
  console.log("\n📝 POST-DEPLOYMENT CHECKLIST:");
  console.log("   [ ] Save contract address to backend .env file");
  console.log("   [ ] Backup contract address to secure location");
  console.log("   [ ] Verify contract on block explorer");
  console.log("   [ ] Test score submission");
  console.log("   [ ] Test leaderboard creation");
  console.log("   [ ] Create first snapshot");
  console.log("   [ ] Monitor deployer wallet balance daily");
  console.log("   [ ] Set up balance alerts (< 50 0G)");
  console.log("   [ ] Document deployment in team records");

  // Final balance
  const finalBalance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("\n💰 Remaining balance:", hre.ethers.formatEther(finalBalance), "0G");
  console.log("💸 Deployment cost:", hre.ethers.formatEther(balance - finalBalance), "0G");

  console.log("\n✨ Deployment complete! Update your backend .env and restart the server.");
  console.log("🚨 REMEMBER: Keep your private key secure and NEVER commit it to git!\n");

  rl.close();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ DEPLOYMENT FAILED:", error);
    rl.close();
    process.exit(1);
  });