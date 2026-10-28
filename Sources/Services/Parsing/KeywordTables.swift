import Foundation

/// Keyword vocabularies used by the heuristic parser.
///
/// The lists are intentionally data (not code) so that adding a customer
/// segment later is a one-line change with a test, which is what the SDD loop
/// in the assignment asks for: spec -> rule -> test -> regression.
enum KeywordTables {
    /// Job titles, longest first so that "Technical Director" wins over
    /// "Director" when both match.
    static let jobTitles: [String] = [
        // Chinese
        "高级工程师", "主任工程师", "技术总监", "市场经理", "客户经理", "项目经理", "运营总监",
        "创意总监", "外贸经理", "算法工程师", "高级顾问", "副总经理", "总经理", "副总裁", "总裁",
        "副教授", "教授", "讲师", "研究员", "副研究员", "工程师", "架构师", "设计师", "分析师",
        "合伙人", "主任", "总监", "经理", "主管", "专员", "顾问", "律师", "医生", "院长", "所长",
        "董事", "秘书", "助理", "代表", "讲师", "博士后", "博士生导师",
        // English
        "Chief Executive Officer", "Chief Technology Officer", "Chief Operating Officer",
        "Chief Financial Officer", "Vice President", "General Manager", "Senior Director",
        "Technical Director", "Academic Director", "Product Manager", "Project Manager",
        "Operations Manager", "Marketing Manager", "Site Manager", "Senior Manager",
        "Senior Consultant", "Senior Engineer", "Staff Engineer", "Chief Engineer",
        "Data Scientist", "Investment Analyst", "Creative Lead", "Business Development",
        "Head of Procurement", "Head of", "Co-Founder", "Founder", "President", "Director",
        "Manager", "Engineer", "Architect", "Designer", "Analyst", "Consultant", "Partner",
        "Professor", "Associate Professor", "Lecturer", "Scientist", "Specialist",
        "Coordinator", "Executive", "Officer", "Lead", "Chief", "CEO", "CTO", "CFO", "COO",
        "VP", "AVP", "PM", "Owner", "Principal",
    ]

    /// Organization suffixes / markers.
    static let companyMarkers: [String] = [
        // Chinese
        "股份有限公司", "有限公司", "有限责任公司", "集团", "公司", "大学", "学院", "研究院",
        "研究所", "设计院", "银行", "事务所", "工作室", "传媒", "医院", "学校", "中心", "商行",
        "物流", "置业", "电力",
        // Note: bare "科技" / "股份" / "企业" are NOT markers on purpose — they
        // appear inside addresses ("科技园南路") and caused the address line to
        // be read as the company name.
        // English
        "Technologies", "Technology", "Analytics", "Consulting", "Solutions", "Systems",
        "Logistics", "Robotics", "Semiconductors", "Semiconductor", "University", "Institute",
        "College", "School", "Laboratory", "Labs", "Studio", "Partners", "Capital",
        "Holdings", "Group", "Bank", "Corporation", "Corp.", "Corp", "Incorporated",
        "Limited", "Ltd.", "Ltd", "LLC", "Inc.", "Inc", "GmbH", "AG", "BV", "NV", "PLC",
        "Pty", "Co.", "Company", "Energy", "Health", "Legal", "Design", "Media", "Agency",
        "Foundation", "Ventures", "Securities", "Insurance", "Freight", "Construction",
        "Chemicals", "Education", "Partners", "Systems", "Physics",
    ]

    /// Department / division markers. Lower weight than company markers because
    /// "School of Computer Science" is a department inside a university.
    static let departmentMarkers: [String] = [
        "学院", "学部", "系", "事业部", "研发中心", "实验室", "研究室", "分公司", "部门",
        "工程部", "市场部", "运营部", "技术部", "销售部", "采购部", "财务部", "人事部",
        "Department", "Division", "Laboratory", "Lab", "Team", "Center", "Centre",
        "School of", "College of", "Faculty of", "Department of", "School", "College",
        "Faculty", "Institute",
        "Engineering", "Operations", "R&D", "Research", "Marketing", "Finance", "Sales",
        "Platform", "Product", "Design", "Supply Chain", "Curriculum", "Delivery",
        "Equity", "Accounts", "Intellectual Property", "Motion Control", "Analog Design",
        "Clinical Products", "Brand Design", "Ocean Freight", "Growth Equity",
        "Project Delivery", "Middle East", "AI Lab", "Global Accounts",
    ]

    /// Address markers, weighted: administrative divisions are strong signals.
    static let addressStrongMarkers: [String] = [
        "省", "市", "区", "县", "镇", "村", "路", "街", "道", "号", "大厦", "广场", "楼层",
        "室", "邮编",
        "Street", "St.", "Road", "Rd.", "Avenue", "Ave.", "Boulevard", "Suite", "Floor",
        "Building", "Bldg.", "District", "Park", "Plaza", "Postal", "Strasse", "Straße",
        "Rue", "Via", "Calle", "Lane", "Drive", "Court", "Way",
    ]

    static let addressWeakMarkers: [String] = [
        "CA", "NY", "TX", "WA", "MA", "IL", "London", "Berlin", "Singapore", "Germany",
        "China", "USA", "United States", "UK", "Japan", "Room", "Tower", "Center",
    ]

    /// Honorifics stripped from a name line ("Dr. David Chen" -> "David Chen").
    static let honorifics: [String] = [
        "Dr.", "Dr", "Prof.", "Prof", "Mr.", "Mr", "Ms.", "Ms", "Mrs.", "Mrs", "Sir",
        "博士", "教授", "先生", "女士", "老师",
    ]

    /// The two patterns below are compile-time constants validated by
    /// `KeywordTablesTests`; a `try!` here can only fail if the source itself
    /// changes into something invalid, which the test turns into a build failure.
    static let emailRegex = try! NSRegularExpression( // swiftlint:disable:this force_try

        pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
        options: []
    )

    static let websitePattern =
        #"(?i)(?<![a-z0-9_@.\-])((?:https?://)?(?:[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\.)+"#
            + #"[a-z]{2,63}(?![a-z0-9_\-]|\.[a-z0-9\-])(?:/[^\s]*)?)"#

    static let websiteRegex = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: websitePattern,
        options: []
    )
}
