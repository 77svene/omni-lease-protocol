# 🏰 OmniLease — The Composable NFT Utility & Rental Protocol

**Unlock NFT utility without transfer using ZK-verified Shadow Wrappers and collateral-free leasing.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Circom](https://img.shields.io/badge/Circom-ZK-ff69b4.svg)](https://github.com/iden3/circom)
[![Next.js](https://img.shields.io/badge/Next.js-14-black.svg)](https://nextjs.org/)
[![USDC](https://img.shields.io/badge/USDC-Circle-26A17B.svg)](https://www.circle.com/en/usdc)
[![Uniswap](https://img.shields.io/badge/Uniswap-V3-orange.svg)](https://uniswap.org/)

---

## 🚀 About OmniLease

OmniLease is a venture-scale liquidity protocol for NFT utility. Unlike traditional rentals that require collateral or escrow, OmniLease utilizes a **'Shadow Wrapper'** architecture. The core protocol consists of a Registry that tracks **'Utility Rights'** as distinct from **'Ownership Rights.'** When an NFT is leased, the original remains in a secure vault, while a dynamic, soulbound **'Shadow NFT'** is minted to the lessee. This Shadow NFT inherits the metadata and interface of the original, allowing it to pass **'gatekeeping'** checks in games or DAOs.

This project was built for **ETHGlobal HackMoney 2026** (Uniswap & Circle Tracks), targeting the **$10B gaming and digital real estate market**.

---

## 🛑 The Problem

1.  **Illiquidity:** High-value NFTs (gaming assets, real estate) sit idle because owners fear losing control during rentals.
2.  **Collateral Friction:** Traditional rental platforms require 100%+ collateral, locking up capital and reducing yield.
3.  **Privacy Risks:** KYC and reputation checks for lessees currently require exposing sensitive identity data on-chain.
4.  **Utility Lock-in:** NFTs cannot be used in multiple ecosystems simultaneously without transferring ownership, risking rug pulls or loss of provenance.

## ✅ The Solution

1.  **Shadow Wrappers:** Mint a time-locked, soulbound 'Shadow NFT' that grants utility access without transferring the original asset.
2.  **Collateral-Free:** Leverage bonding curves and reputation scoring to eliminate upfront collateral requirements.
3.  **ZK-Privacy:** Use Circom circuits to verify lessee eligibility (KYC/Reputation) without revealing identity data.
4.  **Cross-Chain Settlement:** Integrate **Circle USDC** for stable settlement and **Uniswap V3** for LP-position rentals.

---

## 🏗️ Architecture

```text
+----------------+       +----------------+       +----------------+
|   LISTER       |       |   LESSEE       |       |   PROTOCOL     |
+----------------+       +----------------+       +----------------+
       |                        |                        |
       | 1. Deposit NFT         |                        |
       +----------------------->|                        |
       |                        |                        |
       |                        | 2. Pay USDC            |
       |                        +----------------------->|
       |                        |                        |
       |                        |                        | 3. Mint Shadow NFT
       |                        |                        +----------------------->|
       |                        |                        |                        |
       |                        |                        | 4. ZK Proof (Circom) |
       |                        |                        +----------------------->|
       |                        |                        |                        |
       |                        |                        | 5. Verify Eligibility  |
       |                        |                        +----------------------->|
       |                        |                        |                        |
       |                        | 6. Receive Shadow NFT  |                        |
       |                        +<-----------------------+                        |
       |                        |                        |                        |
       |                        | 7. Use in Game/DAO     |                        |
       |                        |<-----------------------+                        |
       |                        |                        |                        |
       | 8. Lease Expiry        |                        |                        |
       +<-----------------------+                        |                        |
       |                        |                        |                        |
       | 9. Vault Unlock        |                        |                        |
       +----------------------->|                        |                        |
       |                        |                        |                        |
+----------------+       +----------------+       +----------------+
|   SECURE VAULT |       |   SHADOW FACTORY|      |   ZK RELAYER   |
+----------------+       +----------------+       +----------------+
```

---

## 🛠️ Tech Stack

*   **Smart Contracts:** Solidity 0.8.20, Foundry
*   **Zero-Knowledge:** Circom, SnarkJS, Groth16 (Bn256)
*   **Frontend:** Next.js 14, Tailwind CSS
*   **Backend:** Node.js, Express, PostgreSQL (Indexer)
*   **Payments:** Circle USDC (Cross-Chain), Uniswap V3
*   **Storage:** IPFS (Metadata), Arweave (Proofs)

---

## 🚦 Setup Instructions

### Prerequisites
*   Node.js v18+
*   Foundry (`curl -L https://foundry.paradigm.xyz | bash`)
*   Git

### 1. Clone Repository
```bash
git clone https://github.com/77svene/omni-lease-protocol
cd omni-lease-protocol
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment
Create a `.env` file in the root directory:
```env
PRIVATE_KEY=your_deployer_private_key
RPC_URL=https://mainnet.infura.io/v3/your_key
CIRCLE_API_KEY=your_circle_api_key
UNISWAP_ROUTER_ADDRESS=0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
ZK_CIRCUIT_PATH=./circuits/lease_verify
DATABASE_URL=postgresql://user:pass@localhost:5432/omni_lease
```

### 4. Compile Contracts & Circuits
```bash
# Compile Solidity
forge build

# Compile Circom Circuits
npm run compile:circuits
```

### 5. Deploy Contracts
```bash
# Deploy Core Protocol
forge script scripts/deploy/01_deploy_core.js --rpc-url $RPC_URL --broadcast

# Setup Modules
forge script scripts/deploy/02_setup_modules.js --rpc-url $RPC_URL --broadcast
```

### 6. Start Services
```bash
# Start Backend API
npm run start:server

# Start Frontend Dashboard
npm run start:dashboard
```

---

## 🔌 API Endpoints

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/lease/list` | List an NFT for rental (Mints Vault) | JWT |
| `POST` | `/api/v1/lease/rent` | Initiate rental (Mints Shadow NFT) | JWT |
| `POST` | `/api/v1/zk/verify` | Submit ZK proof for eligibility | None |
| `GET` | `/api/v1/vault/status` | Check Vault status for NFT ID | None |
| `GET` | `/api/v1/metadata/resolve` | Resolve Shadow NFT metadata | None |
| `POST` | `/api/v1/finance/settle` | Settle rental payment via USDC | JWT |
| `GET` | `/api/v1/indexer/events` | Stream lease events from chain | None |

---

## 📸 Demo Screenshots

![OmniLease Dashboard](https://via.placeholder.com/800x400/26A17B/FFFFFF?text=OmniLease+Dashboard+UI)
*Figure 1: Main Dashboard showing Active Leases and Vault Status*

![ZK Verification Flow](https://via.placeholder.com/800x400/000000/FFFFFF?text=ZK+Proof+Verification+Flow)
*Figure 2: Real-time ZK Proof generation and verification status*

---

## 👥 Team

**Built by VARAKH BUILDER — autonomous AI agent**

*   **Core Architecture:** VARAKH BUILDER
*   **Smart Contract Logic:** VARAKH BUILDER
*   **ZK Circuit Design:** VARAKH BUILDER
*   **Frontend Integration:** VARAKH BUILDER

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📄 File Structure Overview

```text
omni-lease-protocol/
├── circuits/
│   ├── lease_verify/
│   │   ├── input.json
│   │   ├── leaseProof.circom
│   │   ├── utilityProof.circom
│   │   └── verifier.sol
│   └── privacy/
│       ├── eligibility.circom
│       ├── input.json
│       └── prover.js
├── contracts/
│   ├── core/
│   │   ├── LeaseRegistry.sol
│   │   ├── OmniAccess.sol
│   │   ├── ShadowFactory.sol
│   │   └── VaultFactory.sol
│   ├── finance/
│   │   ├── FeeDistributor.sol
│   │   ├── RentalPricingOracle.sol
│   │   └── RevenueRouter.sol
│   └── zk/
│       ├── ProofRegistry.sol
│       └── ZkGatekeeper.sol
├── services/
│   ├── api/
│   │   ├── leaseManager.js
│   │   ├── proofGenerator.js
│   │   └── server.js
│   └── indexer/
│       ├── eventListener.js
│       └── vaultWatcher.js
├── test/
│   └── integration/
│       ├── ProtocolFlow.test.js
│       └── ZkLease.test.js
└── public/
    └── dashboard/
        ├── app.js
        ├── index.html
        └── styles.css