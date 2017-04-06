import PackageDescription

let package = Package(
    name: "GlassHousesServer",
    dependencies: [
        .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 1, minor: 5),
        .Package(url: "https://github.com/vapor/postgresql-provider", majorVersion: 1, minor: 1),
        .Package(url:"https://github.com/mludi/vapor-apns.git", Version(1, 2, 3))
    ],
    exclude: [
        "Config",
        "Database",
        "Localization",
        "Public",
        "Resources",
    ]
)

