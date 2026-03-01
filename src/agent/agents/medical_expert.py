"""Medical Expert agent — STUB.

Returns hardcoded post-vaccine guidance based on AAP/CDC recommendations.

TODO: Replace with Bedrock Knowledge Base RAG retrieval.
TODO: Use langchain_aws.ChatBedrockConverse for LLM-based interpretation.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage

from agent.models.outputs import Citation, MedicalInsight, RiskLevel
from agent.models.state import AgentState


def medical_expert_node(state: AgentState) -> dict:
    """Provide medical guidance based on trend analysis.

    TODO: Implement Bedrock KB retrieval using langchain_aws.
    TODO: Use the trend_analysis from state to form targeted queries.
    """
    trend = state.get("trend_analysis")

    # Check if vaccine correlation was detected
    has_vaccine_correlation = False
    if trend and trend.correlations:
        has_vaccine_correlation = any(
            "VACCINE" in c.upper() for c in trend.correlations
        )

    if has_vaccine_correlation:
        insight = MedicalInsight(
            summary=(
                "Post-vaccination behavioral changes (reduced feeding, increased sleepiness) "
                "are normal and expected within 48-72 hours of DTaP vaccination. "
                "These are signs of a healthy immune response."
            ),
            risk_level=RiskLevel.LOW,
            recommendations=[
                "Continue offering regular feedings; slight reduction (10-20%) is normal post-vaccine.",
                "Extra sleep is expected — allow baby to rest but maintain wake windows for feeding.",
                "Monitor for fever; acetaminophen (infant Tylenol) may be given per pediatrician's dosing.",
                "Seek immediate care if: fever >101°F persists >48h, inconsolable crying >3h, or refusal to eat >24h.",
            ],
            citations=[
                Citation(
                    source_type="book",
                    reference="AAP Immunization Guide, Chapter 4: Post-Vaccination Care",
                    detail="Expected side effects of DTaP in infants 2-6 months",
                ),
                Citation(
                    source_type="medical",
                    reference="CDC Vaccine Information Statement: DTaP",
                    detail="Common reactions and when to call the doctor",
                ),
            ],
        )
    else:
        insight = MedicalInsight(
            summary=(
                "The observed changes in feeding and sleep patterns should be monitored. "
                "For a 4-month-old, variations can be related to growth spurts or developmental milestones."
            ),
            risk_level=RiskLevel.LOW,
            recommendations=[
                "Track feeding volumes for the next 48 hours.",
                "Ensure adequate wet diapers (6+ per day) as hydration indicator.",
                "Consult pediatrician if patterns persist beyond 3 days.",
            ],
            citations=[
                Citation(
                    source_type="book",
                    reference="AAP Bright Futures: Nutrition, 4th Edition",
                    detail="Normal feeding variation in 4-month-olds",
                ),
            ],
        )

    return {
        "medical_insight": insight,
        "agents_completed": ["medical_expert"],
        "messages": [AIMessage(
            content=f"[medical_expert] {insight.summary}",
            name="medical_expert",
        )],
    }
