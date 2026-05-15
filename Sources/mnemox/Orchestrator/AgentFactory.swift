import Foundation

/// Chooses deterministic specialists before [`AgentPool`] materializes them.
public struct AgentFactory: Sendable {
    public init() {}

    public func agents(for task: UserTask, conventions: ConventionProfile) -> [AgentType] {
        let detail = task.detail.lowercased()
        let frameworks = conventions.frameworkTags.joined(separator: " ").lowercased()
        let mentionsUserVisibleText =
            detail.contains("text") || detail.contains("copy") || detail.contains("label")
                || detail.contains("title") || detail.contains("placeholder")

        if matchesFixBug(detail) {
            return [.scanner, .writer, .verifier]
        }

        if matchesRefactor(detail) {
            return [.scanner, .architect, .refactor, .verifier]
        }

        if matchesRenameMove(detail) {
            return [.scanner, .writer, .verifier]
        }

        if matchesAddFeature(detail) {
            return [.scanner, .architect, .writer, .i18n, .test, .verifier]
        }

        if matchesNewComponent(detail) {
            var pipeline: [AgentType] = [.scanner, .architect, .writer]
            if frameworks.contains("nuxt") || frameworks.contains("next") {
                pipeline.append(.i18n)
            }
            pipeline.append(.verifier)
            return pipeline
        }

        if matchesAddProp(detail) {
            var pipeline: [AgentType] = [.scanner, .writer]
            if mentionsUserVisibleText {
                pipeline.append(.i18n)
            }
            pipeline.append(.verifier)
            return pipeline
        }

        return [.scanner, .writer, .verifier]
    }

    private func matchesRenameMove(_ detail: String) -> Bool {
        detail.contains("rename") || detail.contains("move ")
    }

    private func matchesAddProp(_ detail: String) -> Bool {
        detail.contains("add prop") || detail.contains("add property") || detail.contains("new prop")
            || detail.contains("extend props")
    }

    private func matchesNewComponent(_ detail: String) -> Bool {
        detail.contains("new component") || detail.contains("create component")
    }

    private func matchesRefactor(_ detail: String) -> Bool {
        detail.contains("refactor")
    }

    private func matchesAddFeature(_ detail: String) -> Bool {
        detail.contains("add feature") || detail.contains("new feature") || detail.contains("implement feature")
    }

    private func matchesFixBug(_ detail: String) -> Bool {
        detail.contains("fix bug") || detail.contains("bugfix") || detail.contains("regression")
    }
}
