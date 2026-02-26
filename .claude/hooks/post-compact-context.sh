#!/usr/bin/env bash
# Hook: SessionStart (compact) — reinject key project conventions after context compaction
cat <<'EOF'
Post-compaction context reminder:
- Conventional Commits (feat:|fix:|docs:|refactor:|test:|chore:), no Co-Authored-By trailers
- Spec priority: MANIFESTO > API_DESIGN_PRINCIPLE/DATAHUB_INTEGRATION > ARCHITECTURE/USE_CASE > AI_SCAFFOLD > feature/ > feature/spoke/ > impl/
- API routes: /api/v1/spoke/{common,de,da,dg}/, /api/v1/hub/
- DataHub = SSOT for metadata, DataSpoke = computational/analysis layer
- When editing specs, propagate changes both upward and downward through the hierarchy
EOF
exit 0
