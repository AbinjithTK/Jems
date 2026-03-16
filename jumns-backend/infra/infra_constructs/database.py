"""DynamoDB construct — 12 tables with GSIs per design spec."""

from constructs import Construct

import aws_cdk as cdk
import aws_cdk.aws_dynamodb as dynamodb


class DatabaseConstruct(Construct):
    """Creates all DynamoDB tables for the Jumns backend."""

    def __init__(self, scope: Construct, id: str, stage: str) -> None:
        super().__init__(scope, id)

        removal = cdk.RemovalPolicy.DESTROY if stage == "dev" else cdk.RemovalPolicy.RETAIN

        # --- jumns-users (PK: userId) ---
        self.users_table = dynamodb.Table(
            self, "UsersTable",
            table_name=f"jumns-users-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-messages (PK: userId, SK: createdAt#msgId) ---
        self.messages_table = dynamodb.Table(
            self, "MessagesTable",
            table_name=f"jumns-messages-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="createdAt#msgId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-goals (PK: userId, SK: goalId) ---
        self.goals_table = dynamodb.Table(
            self, "GoalsTable",
            table_name=f"jumns-goals-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="goalId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-tasks (PK: userId, SK: taskId) + TasksByGoal GSI ---
        self.tasks_table = dynamodb.Table(
            self, "TasksTable",
            table_name=f"jumns-tasks-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="taskId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )
        self.tasks_table.add_global_secondary_index(
            index_name="TasksByGoal",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="goalId", type=dynamodb.AttributeType.STRING
            ),
        )

        # --- jumns-reminders (PK: userId, SK: reminderId) + ActiveReminders GSI ---
        self.reminders_table = dynamodb.Table(
            self, "RemindersTable",
            table_name=f"jumns-reminders-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="reminderId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-skills (PK: userId, SK: skillId) ---
        self.skills_table = dynamodb.Table(
            self, "SkillsTable",
            table_name=f"jumns-skills-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="skillId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-insights (PK: userId, SK: createdAt#insightId) ---
        self.insights_table = dynamodb.Table(
            self, "InsightsTable",
            table_name=f"jumns-insights-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="createdAt#insightId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-access-codes (PK: code) ---
        self.access_codes_table = dynamodb.Table(
            self, "AccessCodesTable",
            table_name=f"jumns-access-codes-{stage}",
            partition_key=dynamodb.Attribute(
                name="code", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=removal,
        )

        # --- jumns-connections (PK: userId, SK: connectionId) + ConnectionsByStatus GSI ---
        self.connections_table = dynamodb.Table(
            self, "ConnectionsTable",
            table_name=f"jumns-connections-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="connectionId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )
        self.connections_table.add_global_secondary_index(
            index_name="ConnectionsByStatus",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="status", type=dynamodb.AttributeType.STRING
            ),
        )

        # --- jumns-mcp-servers (PK: userId, SK: serverId) ---
        self.mcp_servers_table = dynamodb.Table(
            self, "McpServersTable",
            table_name=f"jumns-mcp-servers-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="serverId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=removal,
        )

        # --- jumns-journal (PK: userId, SK: createdAt#entryId) ---
        self.journal_table = dynamodb.Table(
            self, "JournalTable",
            table_name=f"jumns-journal-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="createdAt#entryId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            point_in_time_recovery=True,
            removal_policy=removal,
        )

        # --- jumns-agent-context (PK: userId, SK: createdAt#ctxId) + TTL ---
        self.agent_context_table = dynamodb.Table(
            self, "AgentContextTable",
            table_name=f"jumns-agent-context-{stage}",
            partition_key=dynamodb.Attribute(
                name="userId", type=dynamodb.AttributeType.STRING
            ),
            sort_key=dynamodb.Attribute(
                name="createdAt#ctxId", type=dynamodb.AttributeType.STRING
            ),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            time_to_live_attribute="ttl",
            removal_policy=removal,
        )

        # Collect all tables for IAM grants
        self.all_tables = [
            self.users_table,
            self.messages_table,
            self.goals_table,
            self.tasks_table,
            self.reminders_table,
            self.skills_table,
            self.insights_table,
            self.access_codes_table,
            self.connections_table,
            self.mcp_servers_table,
            self.journal_table,
            self.agent_context_table,
        ]
