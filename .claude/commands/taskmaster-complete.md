# TaskMaster Complete Task

Complete a TaskMaster task with proper validation and move to the next task.

## Usage

`/taskmaster-complete <task-id>`

## Workflow

1. Verify the current task implementation is complete
2. Run quality gates:
   - `dart format .` - Format code consistently
   - `flutter analyze` - Check for static analysis issues
   - `flutter test` - Run all unit and widget tests
3. Verify builds:
   - `flutter build web` - Verify web compilation
   - `flutter build apk --debug` - Verify Android compilation
4. Mark task as complete: `task-master set-status --id=<task-id> --status=done`
5. Show next available task: `task-master next`

## Example

```bash
# Complete task 3.1
/taskmaster-complete 3.1
```

This will validate task 3.1 is complete, run all quality checks, mark it done, and show the next task.