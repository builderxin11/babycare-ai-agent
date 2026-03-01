"""Social Researcher agent — STUB.

Returns hardcoded Xiaohongshu-style social consensus data.

TODO: Replace with XHS MCP tool calls (mcp run xpzouying/xiaohongshu-mcp).
TODO: Add langchain tool bindings for XHS search.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage

from agent.models.outputs import Citation, SocialInsight
from agent.models.state import AgentState


def social_researcher_node(state: AgentState) -> dict:
    """Fetch social consensus on the topic.

    TODO: Implement Xiaohongshu MCP integration.
    TODO: Perform sentiment analysis on retrieved posts.
    """
    trend = state.get("trend_analysis")

    has_vaccine_topic = False
    if trend and trend.correlations:
        has_vaccine_topic = any(
            "VACCINE" in c.upper() for c in trend.correlations
        )

    if has_vaccine_topic:
        insight = SocialInsight(
            summary=(
                "Among 500+ Xiaohongshu posts about post-vaccine baby care, "
                "the overwhelming consensus (92%) reports that reduced feeding and "
                "increased sleepiness for 1-3 days after DTaP is normal. "
                "Parents recommend extra cuddles, skin-to-skin contact, and patience."
            ),
            consensus_points=[
                "92% of parents report temporary appetite reduction lasting 1-3 days",
                "85% observed increased sleepiness, averaging 1-2 extra hours/day",
                "70% used cool compresses on the injection site to reduce fussiness",
                "Key minority view (8%): some babies show NO behavioral changes post-vaccine",
            ],
            sample_size=523,
            citations=[
                Citation(
                    source_type="xhs_post",
                    reference="XHS Consensus: Post-DTaP Baby Care (N=523)",
                    detail="Aggregated from top-rated posts in #婴儿疫苗 and #宝宝打针后 tags",
                ),
            ],
        )
    else:
        insight = SocialInsight(
            summary=(
                "Among parenting communities, feeding pattern changes in 4-month-olds "
                "are commonly discussed. Most parents report this as a normal phase."
            ),
            consensus_points=[
                "Feeding variations are common during the 4-month sleep regression",
                "Growth spurts can temporarily alter feeding patterns",
            ],
            sample_size=150,
            citations=[
                Citation(
                    source_type="xhs_post",
                    reference="XHS Consensus: 4-Month Baby Feeding (N=150)",
                    detail="Aggregated from #四个月宝宝 tag",
                ),
            ],
        )

    return {
        "social_insight": insight,
        "agents_completed": ["social_researcher"],
        "messages": [AIMessage(
            content=f"[social_researcher] {insight.summary}",
            name="social_researcher",
        )],
    }
