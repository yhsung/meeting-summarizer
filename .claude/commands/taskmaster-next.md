# TaskMaster Next Task

Find the next available TaskMaster task and show its details for immediate work.

## Commands

```bash
# Get next available task
task-master next

# Show detailed task information
task-master show <task-id>
```

## Workflow

1. Run `task-master next` to identify the next task to work on
2. If a task is available, run `task-master show <id>` for full implementation details
3. Begin implementing the task requirements
4. Use `task-master update-subtask --id=<id> --prompt="progress notes"` to track progress

## Usage

Use this command at the start of each development session to continue with the next logical task in the project roadmap.