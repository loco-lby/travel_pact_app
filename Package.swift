// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TravelPact",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TravelPact",
            targets: ["TravelPact"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "TravelPact",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Auth", package: "supabase-swift"),
                .product(name: "Storage", package: "supabase-swift"),
                .product(name: "PostgREST", package: "supabase-swift"),
                .product(name: "Realtime", package: "supabase-swift")
            ],
            path: "TravelPact"
        )
    ]
)