# Agent Cluster Framework - Task Automation

# Default recipe (show help)
default:
    @just --list

# ------------- llm -------------

# Add path comment header to files
path_helper:
    b_path_helper --execute --relative

llm_txt *dirs="nancy src skills":
    b_llm_txt {{ dirs }} --ext="sh" --recursive > docs.llm/src.txt

llm *dirs="nancy src skills": path_helper (llm_txt dirs)
