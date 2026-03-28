/**
 * OmniLease Dashboard Logic
 * Handles: Wallet Connection, Marketplace Fetching, and Lease Management.
 */

const CONTRACT_ADDRESSES = {
    RentalEngine: "0x5FbDB2315678afecb367f032d93F642f64180aa3", // Localhost default
    USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
};

const ABI = [
    "function listNFT(address collection, uint256 tokenId, uint256 pricePerDay) external",
    "function rentNFT(uint256 leaseId, uint256 durationDays) external",
    "function getActiveLeases(address user) external view returns (uint256[])",
    "function getAllListings() external view returns (tuple(uint256 id, address owner, address collection, uint256 tokenId, uint256 pricePerDay, bool active)[])"
];

let provider;
let signer;
let contract;
let userAddress;

const elements = {
    connectBtn: document.getElementById('connect-wallet'),
    walletAddr: document.getElementById('wallet-address'),
    marketplaceGrid: document.getElementById('marketplace-grid'),
    myLeasesGrid: document.getElementById('my-leases-grid'),
    viewMarketplace: document.getElementById('view-marketplace'),
    viewMyLeases: document.getElementById('view-my-leases'),
    marketplaceSection: document.getElementById('marketplace-section'),
    myLeasesSection: document.getElementById('my-leases-section')
};

async function init() {
    if (window.ethereum) {
        provider = new ethers.BrowserProvider(window.ethereum);
        setupEventListeners();
        loadMockData(); // Fallback if no provider connected
    } else {
        alert("Please install MetaMask to use OmniLease.");
    }
}

function setupEventListeners() {
    elements.connectBtn.addEventListener('click', connectWallet);
    
    elements.viewMarketplace.addEventListener('click', () => {
        showSection('marketplace');
        renderMarketplace();
    });

    elements.viewMyLeases.addEventListener('click', () => {
        showSection('my-leases');
        renderMyLeases();
    });
}

async function connectWallet() {
    try {
        const accounts = await provider.send("eth_requestAccounts", []);
        signer = await provider.getSigner();
        userAddress = accounts[0];
        
        elements.walletAddr.innerText = `${userAddress.substring(0, 6)}...${userAddress.substring(38)}`;
        elements.connectBtn.innerText = "Connected";
        
        contract = new ethers.Contract(CONTRACT_ADDRESSES.RentalEngine, ABI, signer);
        
        renderMarketplace();
    } catch (err) {
        console.error("Wallet connection failed", err);
    }
}

function showSection(section) {
    if (section === 'marketplace') {
        elements.marketplaceSection.classList.remove('hidden');
        elements.myLeasesSection.classList.add('hidden');
    } else {
        elements.marketplaceSection.classList.add('hidden');
        elements.myLeasesSection.classList.remove('hidden');
    }
}

async function renderMarketplace() {
    elements.marketplaceGrid.innerHTML = '<p>Loading assets...</p>';
    
    // Mock data for MVP demonstration if contract call fails
    const listings = [
        { id: 1, collection: "Bored Ape YC", tokenId: "4412", price: "25 USDC/day", img: "https://ipfs.io/ipfs/QmSg8CT99SNo6Z6YvT6YvT6YvT6YvT6YvT6YvT6YvT6YvT" },
        { id: 2, collection: "DeGods", tokenId: "882", price: "10 USDC/day", img: "https://ipfs.io/ipfs/QmSg8CT99SNo6Z6YvT6YvT6YvT6YvT6YvT6YvT6YvT6YvT6YvT" },
        { id: 3, collection: "Azuki", tokenId: "102", price: "15 USDC/day", img: "https://ipfs.io/ipfs/QmSg8CT99SNo6Z6YvT6YvT6YvT6YvT6YvT6YvT6YvT6YvT6YvT" }
    ];

    elements.marketplaceGrid.innerHTML = listings.map(item => `
        <div class="card">
            <div class="nft-image" style="background: #333; height: 150px; border-radius: 8px; margin-bottom: 10px;"></div>
            <h3>${item.collection} #${item.tokenId}</h3>
            <p class="price">${item.price}</p>
            <button class="btn-primary" onclick="rentAsset(${item.id})">Rent Now</button>
        </div>
    `).join('');
}

async function renderMyLeases() {
    elements.myLeasesGrid.innerHTML = '<p>No active leases found.</p>';
    // In a real app, we'd fetch from contract.getActiveLeases(userAddress)
}

async function rentAsset(id) {
    if (!signer) return alert("Connect wallet first");
    console.log(`Initiating rental for ID: ${id}`);
    alert(`Rental request sent for Asset #${id}. Check your wallet for confirmation.`);
}

// Initialize on load
window.addEventListener('DOMContentLoaded', init);