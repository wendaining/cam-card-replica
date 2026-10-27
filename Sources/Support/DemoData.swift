import Foundation

/// Deterministic seed data for UI tests, previews and the "first launch" story.
enum DemoData {
    static let cards: [BusinessCard] = [
        BusinessCard(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "朱宏明",
            company: "同济大学",
            jobTitle: "教授",
            department: "计算机科学与技术学院",
            phones: [
                PhoneNumber(kind: .mobile, number: "+86 138 0000 1234"),
                PhoneNumber(kind: .office, number: "021-6000 1234"),
            ],
            emails: ["zhuhongming@example.com"],
            website: "www.example.edu",
            address: "上海市杨浦区四平路1239号 200092",
            notes: "2026 移动计算会议认识",
            tags: ["Conference", "Professor"],
            rawText: "朱宏明\n教授\n同济大学",
            createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_760_000_000)
        ),
        BusinessCard(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Emily Zhang",
            company: "Northwind Analytics",
            jobTitle: "Senior Data Scientist",
            department: "AI Lab",
            phones: [PhoneNumber(kind: .mobile, number: "+1 212 000 5678")],
            emails: ["emily.zhang@example.org"],
            website: "www.northwind.example",
            address: "500 Market Street, Suite 900, San Francisco, CA 94105",
            tags: ["Customer"],
            createdAt: Date(timeIntervalSince1970: 1_760_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_760_100_000)
        ),
        BusinessCard(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "David Chen",
            company: "ABC Technologies",
            jobTitle: "Technical Director",
            phones: [PhoneNumber(kind: .mobile, number: "+1 415 000 1234")],
            emails: ["david.chen@example.com"],
            tags: ["Partner"],
            createdAt: Date(timeIntervalSince1970: 1_760_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_760_200_000)
        ),
    ]

    static let tags: [CardTag] = [
        CardTag(name: "Conference"),
        CardTag(name: "Professor"),
        CardTag(name: "Customer"),
        CardTag(name: "Partner"),
    ]
}
