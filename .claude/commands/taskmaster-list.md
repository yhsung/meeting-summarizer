# TaskMaster List Tasks

Show all current tasks with their status and priorities.

## Commands

```bash
# Show all tasks with status
task-master list

# Show specific task details
task-master show <task-id>

# Show complexity analysis
task-master complexity-report
```

## Task Management

```bash
# Add new task with AI assistance
task-master add-task --prompt="description" --research

# Update existing task
task-master update-task --id=<task-id> --prompt="changes"

# Add implementation notes to subtask
task-master update-subtask --id=<task-id> --prompt="implementation notes"

# Expand task into subtasks
task-master expand --id=<task-id> --research --force
```

## Usage

Use this command to get an overview of all project tasks, their current status, and to manage task lifecycle.