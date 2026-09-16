# LOG QUERY PROTOCOL

Role: ARCHIVIST (Query Mode)

## Trigger

- **ACTIVATE** only when the USER explicitly requests to search, review, or trace session logs.

## Protocol

### Step 1 - List Available Logs

```bash
ls -t <workspace>/.agents/memories/sessions/*-sessionlog.json 2>/dev/null || ls -t ~/.agents/memories/sessions/*-sessionlog.json
```

### Step 2 - Read and Search

- **READ** relevant log files based on USER intent (date, topic, keyword, or full history).
- **PRESENT** facts from the logs as-is without interpretation.
- **DO NOT** write, update, or delete any log file.

### Step 3 - Output

- **REPORT** findings neutrally:

```text
[LOKA-LOG QUERY]
-----------------------------
Logs found  : <count>
Range       : <oldest> -> <newest>
Match       : <what was found>
-----------------------------
```
