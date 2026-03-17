-- Schema: agent
-- Domain 6: RAG Agent & Memory System
-- This file contains all table and function definitions for AI assistant features
-- Edit this file in-place to modify the schema

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS agent;
CREATE EXTENSION IF NOT EXISTS vector;

-- Plant knowledge base documents for RAG
-- These will be chunked and embedded for semantic search
CREATE TABLE IF NOT EXISTS agent.knowledge_documents (
    id              BIGSERIAL PRIMARY KEY,
    plant_species_id BIGINT REFERENCES plants.species(id),  -- Optional: link to specific plant
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,                              -- Full document content
    document_type   TEXT NOT NULL CHECK (document_type IN ('care_guide', 'fact_sheet', 'article', 'faq', 'other')),
    source_url      TEXT,                                       -- Optional: where this info came from
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Chunked and embedded content for RAG retrieval
-- Each document is split into smaller chunks for better semantic search
CREATE TABLE IF NOT EXISTS agent.knowledge_chunks (
    id              BIGSERIAL PRIMARY KEY,
    document_id     BIGINT NOT NULL REFERENCES agent.knowledge_documents(id) ON DELETE CASCADE,
    chunk_text      TEXT NOT NULL,                              -- The actual text chunk
    chunk_index     INTEGER NOT NULL,                           -- Order within the document
    embedding       vector(1536),                               -- OpenAI ada-002 or similar (adjust dimensions as needed)
    metadata        JSONB,                                      -- Additional metadata (section headers, tags, etc.)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, chunk_index)
);

-- Chat conversations between users and the agent
CREATE TABLE IF NOT EXISTS agent.conversations (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES auth0.users(id) ON DELETE SET NULL,
    plant_species_id BIGINT REFERENCES plants.species(id),  -- Optional: if conversation is about a specific plant
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Individual messages within conversations
CREATE TABLE IF NOT EXISTS agent.conversation_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL REFERENCES agent.conversations(id) ON DELETE CASCADE,
    sender_type     TEXT NOT NULL CHECK (sender_type IN ('user', 'assistant')),
    message_text    TEXT NOT NULL,
    metadata        JSONB,                                      -- Can store retrieved doc IDs, tokens used, etc.
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User memory system (agentic memory)
-- Agent stores facts/preferences about users for personalization
CREATE TABLE IF NOT EXISTS agent.user_memories (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES auth0.users(id) ON DELETE CASCADE,
    memory_type     TEXT NOT NULL CHECK (memory_type IN ('preference', 'fact', 'interest', 'goal', 'other')),
    content         TEXT NOT NULL,                              -- e.g. "User likes desert plants and cacti"
    importance      INTEGER DEFAULT 5 CHECK (importance >= 1 AND importance <= 10),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_knowledge_documents_plant_species_id ON agent.knowledge_documents(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_documents_document_type ON agent.knowledge_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_documents_updated_at ON agent.knowledge_documents(updated_at);
CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_document_id ON agent.knowledge_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_chunk_index ON agent.knowledge_chunks(chunk_index);

-- Vector similarity search index (using ivfflat or hnsw depending on pgvector version)
-- Adjust lists parameter based on your dataset size
CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_embedding ON agent.knowledge_chunks
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON agent.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_plant_species_id ON agent.conversations(plant_species_id);
CREATE INDEX IF NOT EXISTS idx_conversations_started_at ON agent.conversations(started_at);
CREATE INDEX IF NOT EXISTS idx_conversations_last_activity_at ON agent.conversations(last_activity_at);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation_id ON agent.conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_sender_type ON agent.conversation_messages(sender_type);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_created_at ON agent.conversation_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_user_memories_user_id ON agent.user_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_user_memories_memory_type ON agent.user_memories(memory_type);
CREATE INDEX IF NOT EXISTS idx_user_memories_importance ON agent.user_memories(importance);
CREATE INDEX IF NOT EXISTS idx_user_memories_last_accessed_at ON agent.user_memories(last_accessed_at);

-- Schema Permissions
-- Grant full permissions to postgres role
GRANT ALL ON SCHEMA agent TO postgres;

-- Grant usage to authenticated and anon roles
GRANT USAGE ON SCHEMA agent TO authenticated, anon;

-- Grant all privileges on all future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA agent GRANT ALL ON TABLES TO postgres;

-- Grant select/insert/update/delete to authenticated users on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA agent GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- Grant usage on sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA agent GRANT USAGE ON SEQUENCES TO postgres, authenticated;

-- Grant execute on functions
ALTER DEFAULT PRIVILEGES IN SCHEMA agent GRANT EXECUTE ON FUNCTIONS TO postgres, authenticated;

