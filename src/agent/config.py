"""Environment-based configuration for the agent system."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class AgentConfig:
    """Immutable runtime configuration loaded from environment variables."""

    aws_region: str = "us-west-2"

    # Model IDs (Bedrock)
    sonnet_model_id: str = "us.anthropic.claude-sonnet-4-20250514-v1:0"
    opus_model_id: str = "us.anthropic.claude-opus-4-6-v1"

    # Bedrock Knowledge Base
    bedrock_kb_id: str = ""  # env: BEDROCK_KB_ID

    # Xiaohongshu MCP server
    xhs_mcp_url: str = ""  # env: XHS_MCP_URL

    # Feature flags
    use_mock_data: bool = True
    use_dynamodb_checkpointer: bool = False

    # Agent thresholds
    confidence_threshold: float = 0.8
    max_critique_iterations: int = 2

    @classmethod
    def from_env(cls) -> AgentConfig:
        """Build config from environment variables with sensible defaults."""
        return cls(
            aws_region=os.getenv("AWS_REGION", "us-west-2"),
            sonnet_model_id=os.getenv(
                "SONNET_MODEL_ID",
                "us.anthropic.claude-sonnet-4-20250514-v1:0",
            ),
            opus_model_id=os.getenv(
                "OPUS_MODEL_ID",
                "us.anthropic.claude-opus-4-6-v1",
            ),
            bedrock_kb_id=os.getenv("BEDROCK_KB_ID", ""),
            xhs_mcp_url=os.getenv("XHS_MCP_URL", ""),
            use_mock_data=os.getenv("USE_MOCK_DATA", "true").lower() == "true",
            use_dynamodb_checkpointer=os.getenv(
                "USE_DYNAMODB_CHECKPOINTER", "false"
            ).lower()
            == "true",
            confidence_threshold=float(
                os.getenv("CONFIDENCE_THRESHOLD", "0.8")
            ),
            max_critique_iterations=int(
                os.getenv("MAX_CRITIQUE_ITERATIONS", "2")
            ),
        )


# Singleton used throughout the agent system
config = AgentConfig.from_env()
