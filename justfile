# Agent Cluster Framework - Task Automation

# Default recipe (show help)
default:
    @just --list

check:
    python3 -m compileall -q src/analyze tests
    find . -type f \( -name '*.sh' -o -name 'nancy' \) -print0 | xargs -0 bash -n

build:
    find . -type f \( -name '*.sh' -o -name 'nancy' \) -print0 | xargs -0 bash -n

test:
    python3 -m pytest tests -q

# ------------- llm -------------

# Add path comment header to files
path_helper:
    b_path_helper --execute --relative

llm_txt *dirs="nancy src skills":
    b_llm_txt {{ dirs }} --ext="sh" --recursive > docs.llm/src.txt

llm *dirs="nancy src skills": path_helper (llm_txt dirs)
