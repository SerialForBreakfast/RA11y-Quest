import Darwin
import ScreenAuditKit

let cli = ScreenAuditCLI()
let exitCode = cli.run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    standardOutput: { output in
        print(output)
    },
    standardError: { output in
        fputs(output + "\n", stderr)
    }
)

exit(exitCode)
