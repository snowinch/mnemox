import Foundation

enum ConventionArtifacts {
    static func packageDependencyKeys(root: URL) -> Set<String> {
        let url = root.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var keys = Set<String>()
        if let deps = json["dependencies"] as? [String: Any] {
            keys.formUnion(deps.keys)
        }
        if let devDeps = json["devDependencies"] as? [String: Any] {
            keys.formUnion(devDeps.keys)
        }
        return keys
    }

    static func tsconfigAliases(root: URL) -> [String: String] {
        for name in ["tsconfig.json", "jsconfig.json"] {
            let url = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            return extractCompilerPaths(json)
        }
        return [:]
    }

    static func typescriptStrict(root: URL) -> Bool {
        for name in ["tsconfig.json", "jsconfig.json"] {
            let url = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let compiler = json["compilerOptions"] as? [String: Any],
                  let strict = compiler["strict"] as? Bool else {
                continue
            }
            return strict
        }
        return false
    }

    static func tailwindDetected(root: URL) -> Bool {
        let names = ["tailwind.config.ts", "tailwind.config.js", "tailwind.config.mjs", "tailwind.config.cjs"]
        return names.contains { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    static func requirementsContainsFastAPI(root: URL) -> Bool {
        let url = root.appendingPathComponent("requirements.txt")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }
        return text.range(of: #"\bfastapi\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func nuxtConfigSnippet(root: URL) -> String {
        for name in ["nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs"] {
            let url = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }
            return text
        }
        return ""
    }

    static func scanProfile(root: URL, frameworks: Set<String>, dominantLanguages: [String]) -> ConventionProfile {
        let deps = packageDependencyKeys(root: root)
        let aliases = tsconfigAliases(root: root)
        let tailwind = tailwindDetected(root: root)
        let strict = typescriptStrict(root: root)

        var tags: [String] = []
        for framework in frameworks.sorted() {
            tags.append("@\(framework)")
        }

        if frameworks.contains("spm") == false, FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            tags.append("@spm")
        }

        var rules: [String] = []
        if dominantLanguages.isEmpty == false {
            rules.append("lang:\(dominantLanguages.joined(separator: "+"))")
        }

        if strict {
            rules.append("@ts-strict")
        }

        if tailwind {
            rules.append("style:tailwind-only NO-inline")
        } else {
            rules.append("style:auto NO-inline")
        }

        if deps.isEmpty == false {
            let condensed = deps.sorted().prefix(8).joined(separator: ",")
            rules.append("deps[\(condensed)]")
        }

        let aliasLine = aliasMXF(from: aliases)
        if aliasLine.isEmpty == false {
            rules.append(aliasLine)
        }

        let nuxtText = nuxtConfigSnippet(root: root)
        if frameworks.contains("nuxt"), nuxtText.isEmpty == false {
            if nuxtText.contains("@nuxtjs/i18n") || (nuxtText.contains("modules:[") && nuxtText.contains("i18n")) {
                rules.append("i18n[@nuxtjs/i18n] REQUIRED")
            }
            if nuxtText.contains("components:") {
                rules.append("components:auto ~/components")
            }
        }

        return ConventionProfile(frameworkTags: tags, ruleLines: rules)
    }

    static func detailedProfile(
        root: URL,
        frameworks: Set<String>,
        dominantLanguages: [String],
        testingSignals: TestingSignals,
    ) -> ConventionProfile {
        let base = scanProfile(root: root, frameworks: frameworks, dominantLanguages: dominantLanguages)
        var tags = base.frameworkTags
        var rules = base.ruleLines

        let i18nLine = detectI18n(root: root, frameworks: frameworks)
        if let i18nLine {
            rules.append(i18nLine)
        }

        if frameworks.contains("vue") || frameworks.contains("nuxt") {
            rules.append("components:auto ~/components no-prefix")
        }

        if testingSignals.framework.isEmpty == false {
            rules.append("tests[\(testingSignals.framework)] \(testingSignals.enabled ? "on" : "off")")
        }

        let testerTags = testingSignals.tags
        if testerTags.isEmpty == false {
            tags.append(contentsOf: testerTags)
        }

        return ConventionProfile(frameworkTags: Array(Set(tags)).sorted(), ruleLines: rules)
    }

    struct TestingSignals: Sendable {
        var enabled: Bool
        var framework: String
        var tags: [String]
    }

    static func detectTesting(root: URL, deps: Set<String>) -> TestingSignals {
        var framework = ""
        var tags: [String] = []
        var enabled = false

        if deps.contains("vitest") {
            framework = "vitest"
            enabled = true
            tags.append("@vitest")
        } else if deps.contains("@jest/globals") || deps.contains("jest") {
            framework = "jest"
            enabled = true
            tags.append("@jest")
        }

        if FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            if framework.isEmpty {
                framework = "xctest"
            }
            enabled = true
            tags.append("@xctest")
        }

        return TestingSignals(enabled: enabled, framework: framework, tags: tags)
    }

    static func cappedMXFProfile(_ profile: ConventionProfile, maxTokens: Int = 25) -> ConventionProfile {
        var trimmedTags = profile.frameworkTags
        var trimmedRules = profile.ruleLines

        func measure() -> Int {
            MXFTokenCounter.count(ConventionProfile(frameworkTags: trimmedTags, ruleLines: trimmedRules).encodeToMXF())
        }

        while measure() > maxTokens, trimmedRules.isEmpty == false {
            trimmedRules.removeLast()
        }

        while measure() > maxTokens, trimmedTags.count > 1 {
            trimmedTags.removeLast()
        }

        while measure() > maxTokens, trimmedTags.isEmpty == false {
            trimmedTags.removeLast()
        }

        return ConventionProfile(frameworkTags: trimmedTags, ruleLines: trimmedRules)
    }

    private static func extractCompilerPaths(_ json: [String: Any]) -> [String: String] {
        guard let compilerOptions = json["compilerOptions"] as? [String: Any],
              let paths = compilerOptions["paths"] as? [String: [String]] else {
            return [:]
        }

        var aliases: [String: String] = [:]
        for (pattern, targets) in paths {
            guard let first = targets.first else {
                continue
            }
            let aliasKey = pattern.replacingOccurrences(of: "/*", with: "/")
            let targetValue = first.replacingOccurrences(of: "/*", with: "/")
            aliases[aliasKey] = targetValue
        }
        return aliases
    }

    private static func aliasMXF(from aliases: [String: String]) -> String {
        guard aliases.isEmpty == false else {
            return ""
        }
        let pairs = aliases.keys.sorted().map { key -> String in
            let value = aliases[key] ?? ""
            return "\(key)->\(value)"
        }
        return "aliases[\(pairs.joined(separator: ","))]"
    }

    private static func detectI18n(root: URL, frameworks: Set<String>) -> String? {
        if frameworks.contains("nuxt") {
            let snippet = nuxtConfigSnippet(root: root)
            if snippet.contains("@nuxtjs/i18n") {
                return "i18n[@nuxtjs/i18n] ->locales REQUIRED"
            }
        }

        let localesDir = root.appendingPathComponent("locales")
        if FileManager.default.fileExists(atPath: localesDir.path) {
            return "i18n[manual] ->locales REQUIRED"
        }

        return nil
    }
}
