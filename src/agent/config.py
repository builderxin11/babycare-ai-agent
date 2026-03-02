"""Environment-based configuration for the agent system."""

from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv


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

    # DynamoDB table names (Amplify Gen 2 dynamic names)
    physiology_log_table: str = ""  # env: PHYSIOLOGY_LOG_TABLE
    context_event_table: str = ""  # env: CONTEXT_EVENT_TABLE
    data_lookback_days: int = 7  # env: DATA_LOOKBACK_DAYS

    # Feature flags
    use_dynamodb_checkpointer: bool = False

    # Agent thresholds
    confidence_threshold: float = 0.8
    max_critique_iterations: int = 2

    @classmethod
    def from_env(cls) -> AgentConfig:
        """Build config from environment variables with sensible defaults.

        Loads .env file (if present) before reading os.environ.
        Existing environment variables take precedence over .env values.
        """
        load_dotenv()
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
            physiology_log_table=os.getenv("PHYSIOLOGY_LOG_TABLE", ""),
            context_event_table=os.getenv("CONTEXT_EVENT_TABLE", ""),
            data_lookback_days=int(os.getenv("DATA_LOOKBACK_DAYS", "7")),
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
