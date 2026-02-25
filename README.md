# p2p_ride (Mobile App)

This folder contains the Flutter mobile application for the P2P Cab system.

## Features

- **Rider Interface**: Request rides and pay via the blockchain escrow.
- **Driver Interface**: Accept and complete rides to earn fake INR.
- **Wallet Integration**: Manage your on-chain balance.

## Setup & Running

1. **Install Flutter**: Ensure you have Flutter installed and configured.
2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the App**:
   ```bash
   flutter run
   ```

## Configuration

Update the API base URL in the app's configuration to point to your backend:
- Default: `http://localhost:5000/api`
