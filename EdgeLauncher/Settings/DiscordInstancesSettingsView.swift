import SwiftUI

extension Notification.Name {
    static let discordReloadRequested = Notification.Name("edge.discord.reloadRequested")
}

struct DiscordInstancesSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("각 Discord 앱은 독립된 로그인 세션을 갖습니다. 시작 URL 을 비워두면 기본 페이지(\u{201C}discord.com/app\u{201D})로 열립니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(MessengerInstanceConfig.allInstances, id: \.id) { cfg in
                    DiscordInstanceEditor(config: cfg)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct IconCategory {
    let name: String
    let symbols: [String]
}

private let iconCategories: [IconCategory] = [
    IconCategory(name: "메시지", symbols: [
        "bubble.left.and.bubble.right.fill", "bubble.fill", "bubble.left.fill", "bubble.right.fill",
        "ellipsis.message.fill", "ellipsis.bubble.fill", "text.bubble.fill", "captions.bubble.fill",
        "quote.bubble.fill", "exclamationmark.bubble.fill", "questionmark.bubble.fill",
        "plus.bubble.fill", "checkmark.bubble.fill", "envelope.fill", "envelope.badge.fill",
        "envelope.open.fill", "paperplane.fill", "tray.fill", "mail.stack.fill",
        "megaphone.fill", "speaker.wave.3.fill", "phone.fill", "video.fill",
    ]),
    IconCategory(name: "알림 / 상태", symbols: [
        "bell.fill", "bell.badge.fill", "bell.slash.fill", "alarm.fill",
        "checkmark.circle.fill", "xmark.circle.fill", "exclamationmark.circle.fill",
        "exclamationmark.triangle.fill", "info.circle.fill", "questionmark.circle.fill",
        "shield.fill", "shield.checkered", "lock.fill", "lock.open.fill",
        "key.fill", "wifi", "wifi.slash", "antenna.radiowaves.left.and.right",
    ]),
    IconCategory(name: "사람 / 소셜", symbols: [
        "person.fill", "person.crop.circle.fill", "person.2.fill", "person.3.fill",
        "person.crop.rectangle.fill", "person.badge.plus.fill", "person.badge.shield.checkmark.fill",
        "figure.stand", "figure.walk", "figure.run", "figure.wave",
        "hand.thumbsup.fill", "hand.thumbsdown.fill", "hand.raised.fill", "hands.clap.fill",
        "face.smiling.fill", "heart.fill", "heart.text.square.fill", "eye.fill",
    ]),
    IconCategory(name: "게임 / 미디어", symbols: [
        "gamecontroller.fill", "dpad.fill", "puzzlepiece.fill", "puzzlepiece.extension.fill",
        "music.note", "music.note.list", "guitars.fill", "pianokeys", "metronome.fill",
        "headphones", "earpods", "airpodsmax", "speaker.wave.2.fill",
        "play.fill", "pause.fill", "stop.fill", "backward.fill", "forward.fill",
        "film.fill", "video.bubble.fill", "tv.fill", "play.rectangle.fill",
    ]),
    IconCategory(name: "감정 / 마법", symbols: [
        "star.fill", "star.circle.fill", "sparkles", "wand.and.stars",
        "bolt.fill", "bolt.circle.fill", "flame.fill", "drop.fill",
        "sun.max.fill", "moon.fill", "moon.stars.fill", "cloud.fill",
        "rainbow", "leaf.fill", "tree.fill", "snowflake",
        "gift.fill", "balloon.fill", "party.popper.fill", "trophy.fill",
    ]),
    IconCategory(name: "작업 / 도구", symbols: [
        "briefcase.fill", "case.fill", "suitcase.fill", "hammer.fill", "wrench.fill",
        "wrench.and.screwdriver.fill", "screwdriver.fill", "scissors", "paperclip",
        "pencil", "pencil.tip", "highlighter", "paintbrush.fill", "paintpalette.fill",
        "gear", "gearshape.fill", "gearshape.2.fill", "slider.horizontal.3",
        "bolt.shield.fill", "magnifyingglass", "doc.fill", "doc.text.fill",
        "folder.fill", "archivebox.fill", "tray.full.fill", "externaldrive.fill",
    ]),
    IconCategory(name: "학습 / 책", symbols: [
        "book.fill", "books.vertical.fill", "book.closed.fill", "graduationcap.fill",
        "pencil.and.ruler.fill", "lightbulb.fill", "lightbulb.max.fill", "brain.head.profile",
        "newspaper.fill", "magazine.fill", "calendar", "calendar.badge.clock",
    ]),
    IconCategory(name: "시간", symbols: [
        "clock.fill", "alarm.fill", "stopwatch.fill", "timer", "hourglass",
        "calendar", "calendar.circle.fill", "deskclock.fill",
    ]),
    IconCategory(name: "탈것", symbols: [
        "car.fill", "bus.fill", "tram.fill", "bicycle", "scooter",
        "airplane", "ferry.fill", "sailboat.fill", "fuelpump.fill",
    ]),
    IconCategory(name: "음식 / 음료", symbols: [
        "cup.and.saucer.fill", "mug.fill", "wineglass.fill", "fork.knife", "fork.knife.circle.fill",
        "takeoutbag.and.cup.and.straw.fill", "popcorn.fill", "birthday.cake.fill", "carrot.fill",
        "fish.fill",
    ]),
    IconCategory(name: "스포츠", symbols: [
        "sportscourt.fill", "soccerball", "basketball.fill", "football.fill",
        "tennis.racket", "trophy.fill", "medal.fill", "flag.checkered",
    ]),
    IconCategory(name: "기술 / IoT", symbols: [
        "cpu.fill", "memorychip.fill", "server.rack", "externaldrive.connected.to.line.below.fill",
        "network", "globe", "globe.americas.fill", "house.fill", "house.circle.fill",
        "lightbulb.led.fill", "powerplug.fill", "battery.100", "thermometer",
        "scanner.fill", "printer.fill", "tv.and.hifispeaker.fill", "homepodmini.fill",
    ]),
    IconCategory(name: "위치 / 지도", symbols: [
        "location.fill", "location.north.line.fill", "mappin", "mappin.and.ellipse",
        "map.fill", "globe", "signpost.right.fill", "binoculars.fill",
    ]),
    IconCategory(name: "카메라 / 사진", symbols: [
        "camera.fill", "camera.macro", "photo.fill", "photo.stack.fill",
        "video.fill", "video.badge.plus.fill", "film.fill",
    ]),
    IconCategory(name: "쇼핑 / 금융", symbols: [
        "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill",
        "dollarsign.circle.fill", "wonsign.circle.fill", "eurosign.circle.fill",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "chart.pie.fill",
    ]),
    IconCategory(name: "동물", symbols: [
        "pawprint.fill", "tortoise.fill", "hare.fill", "fish.fill", "bird.fill",
        "ant.fill", "ladybug.fill",
    ]),
    IconCategory(name: "기호 / 형태", symbols: [
        "hashtag", "at", "asterisk", "number", "percent", "questionmark",
        "exclamationmark", "checkmark", "plus", "minus", "multiply",
        "square.fill", "circle.fill", "triangle.fill", "diamond.fill",
        "hexagon.fill", "octagon.fill", "rhombus.fill",
        "rectangle.fill", "rectangle.stack.fill", "square.grid.2x2.fill", "square.grid.3x3.fill",
        "tag.fill", "bookmark.fill", "flag.fill", "pin.fill",
    ]),
    IconCategory(name: "건강 / 운동", symbols: [
        "heart.fill", "cross.case.fill", "pills.fill", "stethoscope",
        "bandage.fill", "bed.double.fill", "figure.run", "figure.yoga",
    ]),
    IconCategory(name: "기타", symbols: [
        "swift", "applelogo", "command", "option", "control",
        "cursorarrow.click.2", "hand.tap.fill", "scribble.variable", "paintbrush.pointed.fill",
    ]),
]

private let allIcons: [String] = {
    var seen = Set<String>()
    var result: [String] = []
    for category in iconCategories {
        for symbol in category.symbols where !seen.contains(symbol) {
            seen.insert(symbol)
            result.append(symbol)
        }
    }
    return result
}()

private struct DiscordInstanceEditor: View {
    let config: MessengerInstanceConfig
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var iconName: String = ""
    @State private var savedToast: Bool = false
    @State private var iconPickerOpen: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: effectiveIconName)
                    .foregroundStyle(Color.accentColor)
                Text(config.defaultTitle)
                    .font(.headline)
                Spacer()
                if savedToast {
                    Label("저장됨", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button {
                    save()
                } label: {
                    Label("저장 및 새로고침", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("이름")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField(config.defaultTitle, text: $title)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("아이콘")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: effectiveIconName)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 36, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.06))
                        )
                    TextField("SF Symbol 이름 (예: bell.fill)", text: $iconName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                    Button {
                        iconPickerOpen.toggle()
                    } label: {
                        Label("선택", systemImage: "square.grid.3x3.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .popover(isPresented: $iconPickerOpen, arrowEdge: .top) {
                        iconPickerGrid
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("시작 URL")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("https://discord.com/channels/서버ID/채널ID", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { save() }
                    Text("비워두면 기본 페이지 — 채널 URL 형식만 허용")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            let defaults = UserDefaults.standard
            title = defaults.string(forKey: config.titleKey) ?? ""
            url = defaults.string(forKey: config.urlKey) ?? ""
            iconName = defaults.string(forKey: config.iconKey) ?? ""
        }
    }

    private var effectiveIconName: String {
        let trimmed = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "bubble.left.and.bubble.right.fill" : trimmed
    }

    private var iconPickerGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(44), spacing: 6), count: 8)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(iconCategories, id: \.name) { category in
                    Text(category.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(category.symbols, id: \.self) { symbol in
                            Button {
                                iconName = symbol
                                save()
                                iconPickerOpen = false
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(effectiveIconName == symbol ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(effectiveIconName == symbol ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 420, height: 440)
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIcon = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(normalizedTitle, forKey: config.titleKey)
        UserDefaults.standard.set(normalizedURL, forKey: config.urlKey)
        UserDefaults.standard.set(normalizedIcon, forKey: config.iconKey)
        NotificationCenter.default.post(
            name: .discordReloadRequested,
            object: nil,
            userInfo: ["instanceID": config.id, "force": true]
        )
        NotificationCenter.default.post(name: .moduleIconChanged, object: nil)
        withAnimation(.easeIn(duration: 0.15)) { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) { savedToast = false }
        }
    }
}
