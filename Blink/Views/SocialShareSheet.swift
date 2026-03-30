import SwiftUI
import Contacts

/// Share sheet for a clip: private link, contacts, public feed.
struct SocialShareSheet: View {
    let entry: VideoEntry
    let onDismiss: () -> Void

    @StateObject private var socialService = SocialShareService.shared
    @State private var showShareLink = false
    @State private var showContacts = false
    @State private var showPublicFeed = false
    @State private var showCopied = false
    @State private var isLoadingContacts = false
    @State private var isCreatingLink = false
    @State private var contacts: [CNContact] = []
    @State private var contactError: String?
    @State private var isSubmittingToFeed = false
    @State private var feedSubmitSuccess = false
    @State private var shareLink: SocialShareService.SharedLink?
    @State private var contactsTask: Task<Void, Never>?
    @State private var feedSubmitTask: Task<Void, Never>?
    @State private var sendTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Clip preview
                        clipPreview
                            .padding(.top, 8)

                        // Share options
                        VStack(spacing: 12) {
                            // Private Link
                            ShareOptionRow(
                                icon: "link",
                                iconColor: Color(hex: "ff3b30"),
                                title: "Private Link",
                                subtitle: isCreatingLink ? "Creating link..." : "Share as an expiring link (3 views, 7 days)"
                            ) {
                                createAndShowPrivateLink()
                            }
                            .disabled(isCreatingLink)

                            // Blink to Friends
                            ShareOptionRow(
                                icon: "person.2.fill",
                                iconColor: Color(hex: "ff6b60"),
                                title: "Blink to Friends",
                                subtitle: "Send directly to a contact"
                            ) {
                                loadContacts()
                            }

                            // Share to Public Feed
                            ShareOptionRow(
                                icon: "globe",
                                iconColor: Color(hex: "8a8a8a"),
                                title: "Share to Public Feed",
                                subtitle: "Add to today's most meaningful moments (anonymous)"
                            ) {
                                submitToPublicFeed()
                            }
                        }
                        .padding(.horizontal, 16)

                        // Existing links
                        if !socialService.activeLinks(for: entry.id).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Links")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "8a8a8a"))
                                    .padding(.horizontal, 16)

                                ForEach(socialService.activeLinks(for: entry.id)) { link in
                                    ActiveLinkRow(link: link) {
                                        socialService.copyShareText(for: entry)
                                        showCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            showCopied = false
                                        }
                                    }
                                }
                            }
                        }

                        if showCopied {
                            Text("Link copied to clipboard!")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "ff3b30"))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 40)
                }

                if isCreatingLink {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color(hex: "ff3b30"))
                            .scaleEffect(1.5)
                        Text("Creating link...")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                    .padding(24)
                    .background(Color(hex: "1e1e1e"))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
            .sheet(isPresented: $showContacts) {
                ContactsPickerView(contacts: contacts, entry: entry) {
                    showContacts = false
                    onDismiss()
                }
            }
            .alert("Contacts Access", isPresented: Binding(
                get: { contactError != nil },
                set: { if !$0 { contactError = nil } }
            )) {
                Button("OK", role: .cancel) {}
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text(contactError ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            contactsTask?.cancel()
            feedSubmitTask?.cancel()
            sendTask?.cancel()
        }
    }

    private var clipPreview: some View {
        HStack(spacing: 12) {
            if let thumbURL = entry.thumbnailURL {
                AsyncImage(url: thumbURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "1e1e1e"))
                }
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
            } else {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                    .fill(Color(hex: "1e1e1e"))
                    .frame(width: 80, height: 60)
                    .overlay(
                        Image(systemName: "video.fill")
                            .foregroundColor(Color(hex: "8a8a8a"))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .lineLimit(2)

                Text(entry.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "8a8a8a"))

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(Int(entry.duration))s")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: "666666"))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: "141414"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        .padding(.horizontal, 16)
    }

    private func createAndShowPrivateLink() {
        isCreatingLink = true
        let link = socialService.createPrivateLink(for: entry)
        shareLink = link
        socialService.copyShareText(for: entry)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
            isCreatingLink = false
        }
    }

    private func loadContacts() {
        isLoadingContacts = true
        contactsTask = Task {
            do {
                let fetchedContacts = try await socialService.fetchRecentContacts()
                await MainActor.run {
                    contacts = fetchedContacts
                    isLoadingContacts = false
                    if fetchedContacts.isEmpty {
                        contactError = "No contacts with phone numbers found."
                    } else {
                        showContacts = true
                    }
                }
            } catch SocialShareService.ContactError.accessDenied {
                await MainActor.run {
                    isLoadingContacts = false
                    contactError = "Contacts access denied. Enable in Settings > Blink > Contacts."
                }
            } catch {
                await MainActor.run {
                    isLoadingContacts = false
                    contactError = error.localizedDescription
                }
            }
        }
    }

    private func submitToPublicFeed() {
        isSubmittingToFeed = true
        feedSubmitTask = Task {
            do {
                try await socialService.submitToPublicFeed(entry: entry)
                await MainActor.run {
                    isSubmittingToFeed = false
                    feedSubmitSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmittingToFeed = false
                }
            }
        }
    }
}

// MARK: - Share Option Row

struct ShareOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "f5f5f5"))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "8a8a8a"))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "555555"))
            }
            .padding(14)
            .background(Color(hex: "141414"))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium))
        }
    }
}

// MARK: - Active Link Row

struct ActiveLinkRow: View {
    let link: SocialShareService.SharedLink
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "ff3b30"))

            VStack(alignment: .leading, spacing: 2) {
                Text(link.shareURL.absoluteString)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "f5f5f5"))
                    .lineLimit(1)

                Text("\(link.viewCount)/\(link.maxViews) views • expires \(link.expiresAt, style: .relative)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "8a8a8a"))
            }

            Spacer()

            Button {
                onCopy()
            } label: {
                Text("Copy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "ff3b30"))
            }
        }
        .padding(12)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
        .padding(.horizontal, 16)
    }
}

// MARK: - Contacts Picker

struct ContactsPickerView: View {
    let contacts: [CNContact]
    let entry: VideoEntry
    let onSelected: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialService = SocialShareService.shared
    @State private var selectedContact: CNContact?
    @State private var showConfirm = false
    @State private var isSending = false
    @State private var sendSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0a0a0a")
                    .ignoresSafeArea()

                if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "8a8a8a"))
                        Text("No contacts found")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "8a8a8a"))
                    }
                } else {
                    List {
                        ForEach(contacts, id: \.identifier) { contact in
                            Button {
                                selectedContact = contact
                                showConfirm = true
                            } label: {
                                HStack(spacing: 12) {
                                    if let imageData = contact.thumbnailImageData,
                                       let contactImage = UIImage(data: imageData) {
                                        Image(uiImage: contactImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(hex: "2a2a2a"))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Text("\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color(hex: "f5f5f5"))
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(contact.givenName) \(contact.familyName)")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color(hex: "f5f5f5"))
                                        if let phone = contact.phoneNumbers.first {
                                            Text(phone.value.stringValue)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "8a8a8a"))
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .listRowBackground(Color(hex: "141414"))
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                }

                if sendSuccess {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "ff3b30"))
                        Text("Copied! Send manually")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "f5f5f5"))
                    }
                }
            }
            .navigationTitle("Send to Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0a0a0a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "ff3b30"))
                }
            }
            .confirmationDialog(
                "Send to \(selectedContact?.givenName ?? "")?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Send") {
                    sendToContact()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A link will be copied to your clipboard. Paste it into a message to send.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sendToContact() {
        guard let contact = selectedContact else { return }
        isSending = true

        sendTask = Task {
            try? await socialService.shareViaMessages(to: contact, entry: entry)
            await MainActor.run {
                isSending = false
                sendSuccess = true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                sendSuccess = false
                onSelected()
            }
        }
    }
}

#Preview {
    SocialShareSheet(
        entry: VideoEntry(date: Date(), filename: "test.mov", duration: 15),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
