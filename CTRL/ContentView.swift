import SwiftUI
import FamilyControls

struct ContentView: View {

    // MARK: - State

    @StateObject private var nfcManager = NFCManager()
    @StateObject private var blockingManager = BlockingManager()
    @ObservedObject private var appState = AppState.shared

    @State private var showAppPicker = false
    @State private var pickerSelection = FamilyActivitySelection()

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 32) {

                // MARK: Status Section

                statusSection

                Spacer()

                // MARK: App Selection Button

                selectAppsButton

                Spacer()

                // MARK: Main Action - NFC Toggle

                nfcToggleButton

                Spacer()

                // MARK: Footer

                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .familyActivityPicker(
            isPresented: $showAppPicker,
            selection: $pickerSelection
        )
        .onChange(of: pickerSelection) {
            appState.saveSelectedApps(pickerSelection)
        }
        .onAppear {
            pickerSelection = appState.selectedApps
        }
        .task {
            let authorized = await blockingManager.requestAuthorization()
            appState.isAuthorized = authorized
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Authorization status
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isAuthorized ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appState.isAuthorized ? "Authorized" : "Not Authorized")
                        .font(.caption)
                        .foregroundColor(appState.isAuthorized ? .green : .red)
                }

                Spacer()

                // Blocking status
                Text(blockingManager.isBlocking ? "BLOCKING" : "NOT BLOCKING")
                    .font(.caption.weight(.bold))
                    .foregroundColor(blockingManager.isBlocking ? .green : Color(.systemGray))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(blockingManager.isBlocking
                                  ? Color.green.opacity(0.15)
                                  : Color(.systemGray).opacity(0.15))
                    )
            }

            // Apps selected count
            HStack {
                Image(systemName: "app.badge")
                    .foregroundColor(Color(.systemGray))
                Text("\(appCount) app\(appCount == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray))
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Select Apps Button

    private var selectAppsButton: some View {
        Button {
            showAppPicker = true
        } label: {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.title3)
                Text("Select Apps to Block")
                    .fontWeight(.medium)
                Spacer()
                Text("\(appCount)")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray))
            }
            .padding(16)
            .foregroundColor(.white)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
        }
    }

    // MARK: - NFC Toggle Button

    private var nfcToggleButton: some View {
        VStack(spacing: 20) {
            Button(action: performNFCScan) {
                ZStack {
                    Circle()
                        .fill(blockingManager.isBlocking
                              ? Color.green.opacity(0.15)
                              : Color.white.opacity(0.08))
                        .frame(width: 140, height: 140)

                    Circle()
                        .stroke(blockingManager.isBlocking
                                ? Color.green.opacity(0.4)
                                : Color.white.opacity(0.15),
                                lineWidth: 2)
                        .frame(width: 140, height: 140)

                    Image(systemName: blockingManager.isBlocking
                          ? "lock.fill"
                          : "lock.open")
                        .font(.system(size: 44))
                        .foregroundColor(blockingManager.isBlocking ? .green : .white)
                }
            }
            .disabled(!nfcManager.isAvailable || nfcManager.isScanning)

            Text("Tap Token to Toggle")
                .font(.headline)
                .foregroundColor(Color(.systemGray))

            if nfcManager.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Scanning...")
                        .font(.subheadline)
                        .foregroundColor(Color(.systemGray))
                }
            }

            if let error = nfcManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("CTRL")
                .font(.footnote.weight(.medium))
                .foregroundColor(Color(.systemGray))
            Text("getctrl.in")
                .font(.caption2)
                .foregroundColor(Color(.systemGray2))
        }
    }

    // MARK: - Helpers

    private var appCount: Int {
        appState.selectedApps.applicationTokens.count + appState.selectedApps.categoryTokens.count
    }

    // MARK: - Actions

    private func performNFCScan() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        nfcManager.scan { result in
            switch result {
            case .success:
                blockingManager.toggleBlocking(for: appState.selectedApps)
                appState.isBlocking = blockingManager.isBlocking
                feedbackGenerator.notificationOccurred(.success)

            case .failure(let error):
                if case NFCError.userCancelled = error {
                    return
                }
                feedbackGenerator.notificationOccurred(.error)
                print("Scan failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
