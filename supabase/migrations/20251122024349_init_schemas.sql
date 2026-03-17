create schema if not exists "agent";

create schema if not exists "auth0";

create schema if not exists "dome";

create schema if not exists "gamification";

create schema if not exists "inventory";

create schema if not exists "staff";

create extension if not exists "vector" with schema "public";

create sequence "agent"."conversation_messages_id_seq";

create sequence "agent"."conversations_id_seq";

create sequence "agent"."knowledge_chunks_id_seq";

create sequence "agent"."knowledge_documents_id_seq";

create sequence "agent"."user_memories_id_seq";

create sequence "auth0"."roles_id_seq";

create sequence "auth0"."users_id_seq";

create sequence "dome"."event_registrations_id_seq";

create sequence "dome"."events_id_seq";

create sequence "dome"."info_pages_id_seq";

create sequence "gamification"."achievements_id_seq";

create sequence "gamification"."plant_discoveries_id_seq";

create sequence "gamification"."qr_codes_id_seq";

create sequence "gamification"."qr_scans_id_seq";

create sequence "gamification"."scrapbooks_id_seq";

create sequence "gamification"."trivia_answers_id_seq";

create sequence "gamification"."trivia_attempts_id_seq";

create sequence "gamification"."trivia_questions_id_seq";

create sequence "gamification"."user_achievements_id_seq";

create sequence "inventory"."plant_instances_id_seq";

create sequence "inventory"."plant_notes_id_seq";

create sequence "inventory"."plant_species_id_seq";

create sequence "inventory"."stock_requests_id_seq";

create sequence "inventory"."storage_locations_id_seq";

create sequence "staff"."announcements_id_seq";

create sequence "staff"."schedules_id_seq";

create sequence "staff"."task_comments_id_seq";

create sequence "staff"."tasks_id_seq";


  create table "agent"."conversation_messages" (
    "id" bigint not null default nextval('agent.conversation_messages_id_seq'::regclass),
    "conversation_id" bigint not null,
    "sender_type" text not null,
    "message_text" text not null,
    "metadata" jsonb,
    "created_at" timestamp with time zone not null default now()
      );



  create table "agent"."conversations" (
    "id" bigint not null default nextval('agent.conversations_id_seq'::regclass),
    "user_id" bigint,
    "plant_species_id" bigint,
    "started_at" timestamp with time zone not null default now(),
    "last_activity_at" timestamp with time zone not null default now()
      );



  create table "agent"."knowledge_chunks" (
    "id" bigint not null default nextval('agent.knowledge_chunks_id_seq'::regclass),
    "document_id" bigint not null,
    "chunk_text" text not null,
    "chunk_index" integer not null,
    "embedding" public.vector(1536),
    "metadata" jsonb,
    "created_at" timestamp with time zone not null default now()
      );



  create table "agent"."knowledge_documents" (
    "id" bigint not null default nextval('agent.knowledge_documents_id_seq'::regclass),
    "plant_species_id" bigint,
    "title" text not null,
    "content" text not null,
    "document_type" text not null,
    "source_url" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "agent"."user_memories" (
    "id" bigint not null default nextval('agent.user_memories_id_seq'::regclass),
    "user_id" bigint not null,
    "memory_type" text not null,
    "content" text not null,
    "importance" integer default 5,
    "created_at" timestamp with time zone not null default now(),
    "last_accessed_at" timestamp with time zone not null default now()
      );



  create table "auth0"."roles" (
    "id" smallint not null default nextval('auth0.roles_id_seq'::regclass),
    "name" text not null
      );



  create table "auth0"."user_roles" (
    "user_id" bigint not null,
    "role_id" smallint not null
      );



  create table "auth0"."users" (
    "id" bigint not null default nextval('auth0.users_id_seq'::regclass),
    "auth0_user_id" text not null,
    "email" text,
    "display_name" text,
    "name" text,
    "given_name" text,
    "family_name" text,
    "picture_url" text,
    "locale" text,
    "profile_metadata" jsonb,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "dome"."event_registrations" (
    "id" bigint not null default nextval('dome.event_registrations_id_seq'::regclass),
    "event_id" bigint not null,
    "user_id" bigint,
    "attendee_name" text not null,
    "attendee_email" text,
    "attendee_phone" text,
    "registration_time" timestamp with time zone not null default now(),
    "status" text not null default 'registered'::text,
    "notes" text
      );



  create table "dome"."events" (
    "id" bigint not null default nextval('dome.events_id_seq'::regclass),
    "title" text not null,
    "description" text,
    "event_type" text not null,
    "start_time" timestamp with time zone not null,
    "end_time" timestamp with time zone not null,
    "location" text,
    "capacity" integer,
    "registration_required" boolean not null default false,
    "registration_url" text,
    "image_url" text,
    "created_by_user_id" bigint,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "dome"."info_pages" (
    "id" bigint not null default nextval('dome.info_pages_id_seq'::regclass),
    "slug" text not null,
    "title" text not null,
    "content" text not null,
    "published" boolean not null default true,
    "display_order" integer,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "gamification"."achievements" (
    "id" bigint not null default nextval('gamification.achievements_id_seq'::regclass),
    "name" text not null,
    "description" text not null,
    "icon_url" text,
    "achievement_type" text not null,
    "threshold" integer,
    "created_at" timestamp with time zone not null default now()
      );



  create table "gamification"."plant_discoveries" (
    "id" bigint not null default nextval('gamification.plant_discoveries_id_seq'::regclass),
    "scrapbook_id" bigint not null,
    "plant_species_id" bigint not null,
    "discovered_at" timestamp with time zone not null default now(),
    "notes" text,
    "favorite" boolean not null default false
      );



  create table "gamification"."qr_codes" (
    "id" bigint not null default nextval('gamification.qr_codes_id_seq'::regclass),
    "code_token" uuid not null,
    "plant_instance_id" bigint not null,
    "active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "gamification"."qr_scans" (
    "id" bigint not null default nextval('gamification.qr_scans_id_seq'::regclass),
    "user_id" bigint,
    "qr_code_id" bigint not null,
    "scanned_at" timestamp with time zone not null default now()
      );



  create table "gamification"."scrapbooks" (
    "id" bigint not null default nextval('gamification.scrapbooks_id_seq'::regclass),
    "user_id" bigint not null,
    "title" text not null,
    "description" text,
    "created_at" timestamp with time zone not null default now()
      );



  create table "gamification"."trivia_answers" (
    "id" bigint not null default nextval('gamification.trivia_answers_id_seq'::regclass),
    "question_id" bigint not null,
    "answer_text" text not null,
    "is_correct" boolean not null default false,
    "explanation" text
      );



  create table "gamification"."trivia_attempts" (
    "id" bigint not null default nextval('gamification.trivia_attempts_id_seq'::regclass),
    "user_id" bigint,
    "question_id" bigint not null,
    "selected_answer_id" bigint,
    "is_correct" boolean not null,
    "attempted_at" timestamp with time zone not null default now()
      );



  create table "gamification"."trivia_questions" (
    "id" bigint not null default nextval('gamification.trivia_questions_id_seq'::regclass),
    "plant_species_id" bigint,
    "question" text not null,
    "difficulty" text not null default 'medium'::text,
    "active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );



  create table "gamification"."user_achievements" (
    "id" bigint not null default nextval('gamification.user_achievements_id_seq'::regclass),
    "user_id" bigint not null,
    "achievement_id" bigint not null,
    "earned_at" timestamp with time zone not null default now()
      );



  create table "inventory"."plant_instances" (
    "id" bigint not null default nextval('inventory.plant_instances_id_seq'::regclass),
    "plant_species_id" bigint not null,
    "storage_location_id" bigint,
    "identifier" text,
    "quantity" integer not null default 1,
    "status" text not null default 'available'::text,
    "acquired_date" date,
    "notes" text,
    "created_at" timestamp with time zone not null default now()
      );



  create table "inventory"."plant_notes" (
    "id" bigint not null default nextval('inventory.plant_notes_id_seq'::regclass),
    "plant_instance_id" bigint not null,
    "staff_user_id" bigint not null,
    "note_type" text not null,
    "content" text not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "inventory"."plant_species" (
    "id" bigint not null default nextval('inventory.plant_species_id_seq'::regclass),
    "scientific_name" text not null,
    "common_name" text,
    "description" text,
    "care_notes" text
      );



  create table "inventory"."stock_requests" (
    "id" bigint not null default nextval('inventory.stock_requests_id_seq'::regclass),
    "requested_by_user_id" bigint not null,
    "plant_species_id" bigint,
    "requested_species_name" text,
    "quantity" integer not null,
    "priority" text not null default 'normal'::text,
    "status" text not null default 'pending'::text,
    "justification" text,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );



  create table "inventory"."storage_locations" (
    "id" bigint not null default nextval('inventory.storage_locations_id_seq'::regclass),
    "name" text not null,
    "location_type" text not null,
    "description" text,
    "capacity" integer,
    "created_at" timestamp with time zone not null default now()
      );



  create table "staff"."announcements" (
    "id" bigint not null default nextval('staff.announcements_id_seq'::regclass),
    "created_by_user_id" bigint not null,
    "title" text not null,
    "content" text not null,
    "priority" text not null default 'normal'::text,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );



  create table "staff"."schedules" (
    "id" bigint not null default nextval('staff.schedules_id_seq'::regclass),
    "user_id" bigint not null,
    "shift_start" timestamp with time zone not null,
    "shift_end" timestamp with time zone not null,
    "role_during_shift" text,
    "notes" text,
    "created_at" timestamp with time zone not null default now()
      );



  create table "staff"."task_comments" (
    "id" bigint not null default nextval('staff.task_comments_id_seq'::regclass),
    "task_id" bigint not null,
    "user_id" bigint not null,
    "comment" text not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "staff"."tasks" (
    "id" bigint not null default nextval('staff.tasks_id_seq'::regclass),
    "created_by_user_id" bigint not null,
    "assigned_to_user_id" bigint,
    "title" text not null,
    "description" text,
    "priority" text not null default 'normal'::text,
    "status" text not null default 'pending'::text,
    "due_date" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter sequence "agent"."conversation_messages_id_seq" owned by "agent"."conversation_messages"."id";

alter sequence "agent"."conversations_id_seq" owned by "agent"."conversations"."id";

alter sequence "agent"."knowledge_chunks_id_seq" owned by "agent"."knowledge_chunks"."id";

alter sequence "agent"."knowledge_documents_id_seq" owned by "agent"."knowledge_documents"."id";

alter sequence "agent"."user_memories_id_seq" owned by "agent"."user_memories"."id";

alter sequence "auth0"."roles_id_seq" owned by "auth0"."roles"."id";

alter sequence "auth0"."users_id_seq" owned by "auth0"."users"."id";

alter sequence "dome"."event_registrations_id_seq" owned by "dome"."event_registrations"."id";

alter sequence "dome"."events_id_seq" owned by "dome"."events"."id";

alter sequence "dome"."info_pages_id_seq" owned by "dome"."info_pages"."id";

alter sequence "gamification"."achievements_id_seq" owned by "gamification"."achievements"."id";

alter sequence "gamification"."plant_discoveries_id_seq" owned by "gamification"."plant_discoveries"."id";

alter sequence "gamification"."qr_codes_id_seq" owned by "gamification"."qr_codes"."id";

alter sequence "gamification"."qr_scans_id_seq" owned by "gamification"."qr_scans"."id";

alter sequence "gamification"."scrapbooks_id_seq" owned by "gamification"."scrapbooks"."id";

alter sequence "gamification"."trivia_answers_id_seq" owned by "gamification"."trivia_answers"."id";

alter sequence "gamification"."trivia_attempts_id_seq" owned by "gamification"."trivia_attempts"."id";

alter sequence "gamification"."trivia_questions_id_seq" owned by "gamification"."trivia_questions"."id";

alter sequence "gamification"."user_achievements_id_seq" owned by "gamification"."user_achievements"."id";

alter sequence "inventory"."plant_instances_id_seq" owned by "inventory"."plant_instances"."id";

alter sequence "inventory"."plant_notes_id_seq" owned by "inventory"."plant_notes"."id";

alter sequence "inventory"."plant_species_id_seq" owned by "inventory"."plant_species"."id";

alter sequence "inventory"."stock_requests_id_seq" owned by "inventory"."stock_requests"."id";

alter sequence "inventory"."storage_locations_id_seq" owned by "inventory"."storage_locations"."id";

alter sequence "staff"."announcements_id_seq" owned by "staff"."announcements"."id";

alter sequence "staff"."schedules_id_seq" owned by "staff"."schedules"."id";

alter sequence "staff"."task_comments_id_seq" owned by "staff"."task_comments"."id";

alter sequence "staff"."tasks_id_seq" owned by "staff"."tasks"."id";

CREATE UNIQUE INDEX conversation_messages_pkey ON agent.conversation_messages USING btree (id);

CREATE UNIQUE INDEX conversations_pkey ON agent.conversations USING btree (id);

CREATE INDEX idx_conversation_messages_conversation_id ON agent.conversation_messages USING btree (conversation_id);

CREATE INDEX idx_conversation_messages_created_at ON agent.conversation_messages USING btree (created_at);

CREATE INDEX idx_conversation_messages_sender_type ON agent.conversation_messages USING btree (sender_type);

CREATE INDEX idx_conversations_last_activity_at ON agent.conversations USING btree (last_activity_at);

CREATE INDEX idx_conversations_plant_species_id ON agent.conversations USING btree (plant_species_id);

CREATE INDEX idx_conversations_started_at ON agent.conversations USING btree (started_at);

CREATE INDEX idx_conversations_user_id ON agent.conversations USING btree (user_id);

CREATE INDEX idx_knowledge_chunks_chunk_index ON agent.knowledge_chunks USING btree (chunk_index);

CREATE INDEX idx_knowledge_chunks_document_id ON agent.knowledge_chunks USING btree (document_id);

CREATE INDEX idx_knowledge_chunks_embedding ON agent.knowledge_chunks USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');

CREATE INDEX idx_knowledge_documents_document_type ON agent.knowledge_documents USING btree (document_type);

CREATE INDEX idx_knowledge_documents_plant_species_id ON agent.knowledge_documents USING btree (plant_species_id);

CREATE INDEX idx_knowledge_documents_updated_at ON agent.knowledge_documents USING btree (updated_at);

CREATE INDEX idx_user_memories_importance ON agent.user_memories USING btree (importance);

CREATE INDEX idx_user_memories_last_accessed_at ON agent.user_memories USING btree (last_accessed_at);

CREATE INDEX idx_user_memories_memory_type ON agent.user_memories USING btree (memory_type);

CREATE INDEX idx_user_memories_user_id ON agent.user_memories USING btree (user_id);

CREATE UNIQUE INDEX knowledge_chunks_document_id_chunk_index_key ON agent.knowledge_chunks USING btree (document_id, chunk_index);

CREATE UNIQUE INDEX knowledge_chunks_pkey ON agent.knowledge_chunks USING btree (id);

CREATE UNIQUE INDEX knowledge_documents_pkey ON agent.knowledge_documents USING btree (id);

CREATE UNIQUE INDEX user_memories_pkey ON agent.user_memories USING btree (id);

CREATE INDEX idx_user_roles_role_id ON auth0.user_roles USING btree (role_id);

CREATE INDEX idx_user_roles_user_id ON auth0.user_roles USING btree (user_id);

CREATE INDEX idx_users_auth0_user_id ON auth0.users USING btree (auth0_user_id);

CREATE INDEX idx_users_email ON auth0.users USING btree (email);

CREATE UNIQUE INDEX roles_name_key ON auth0.roles USING btree (name);

CREATE UNIQUE INDEX roles_pkey ON auth0.roles USING btree (id);

CREATE UNIQUE INDEX user_roles_pkey ON auth0.user_roles USING btree (user_id, role_id);

CREATE UNIQUE INDEX users_auth0_user_id_key ON auth0.users USING btree (auth0_user_id);

CREATE UNIQUE INDEX users_email_key ON auth0.users USING btree (email);

CREATE UNIQUE INDEX users_pkey ON auth0.users USING btree (id);

CREATE UNIQUE INDEX event_registrations_pkey ON dome.event_registrations USING btree (id);

CREATE UNIQUE INDEX events_pkey ON dome.events USING btree (id);

CREATE INDEX idx_event_registrations_event_id ON dome.event_registrations USING btree (event_id);

CREATE INDEX idx_event_registrations_status ON dome.event_registrations USING btree (status);

CREATE INDEX idx_event_registrations_user_id ON dome.event_registrations USING btree (user_id);

CREATE INDEX idx_events_created_by_user_id ON dome.events USING btree (created_by_user_id);

CREATE INDEX idx_events_end_time ON dome.events USING btree (end_time);

CREATE INDEX idx_events_event_type ON dome.events USING btree (event_type);

CREATE INDEX idx_events_start_time ON dome.events USING btree (start_time);

CREATE INDEX idx_info_pages_display_order ON dome.info_pages USING btree (display_order);

CREATE INDEX idx_info_pages_published ON dome.info_pages USING btree (published);

CREATE INDEX idx_info_pages_slug ON dome.info_pages USING btree (slug);

CREATE UNIQUE INDEX info_pages_pkey ON dome.info_pages USING btree (id);

CREATE UNIQUE INDEX info_pages_slug_key ON dome.info_pages USING btree (slug);

CREATE UNIQUE INDEX achievements_name_key ON gamification.achievements USING btree (name);

CREATE UNIQUE INDEX achievements_pkey ON gamification.achievements USING btree (id);

CREATE INDEX idx_achievements_achievement_type ON gamification.achievements USING btree (achievement_type);

CREATE INDEX idx_plant_discoveries_discovered_at ON gamification.plant_discoveries USING btree (discovered_at);

CREATE INDEX idx_plant_discoveries_favorite ON gamification.plant_discoveries USING btree (favorite);

CREATE INDEX idx_plant_discoveries_plant_species_id ON gamification.plant_discoveries USING btree (plant_species_id);

CREATE INDEX idx_plant_discoveries_scrapbook_id ON gamification.plant_discoveries USING btree (scrapbook_id);

CREATE INDEX idx_qr_codes_active ON gamification.qr_codes USING btree (active);

CREATE INDEX idx_qr_codes_code_token ON gamification.qr_codes USING btree (code_token);

CREATE INDEX idx_qr_codes_plant_instance_id ON gamification.qr_codes USING btree (plant_instance_id);

CREATE INDEX idx_qr_scans_qr_code_id ON gamification.qr_scans USING btree (qr_code_id);

CREATE INDEX idx_qr_scans_scanned_at ON gamification.qr_scans USING btree (scanned_at);

CREATE INDEX idx_qr_scans_user_id ON gamification.qr_scans USING btree (user_id);

CREATE INDEX idx_scrapbooks_user_id ON gamification.scrapbooks USING btree (user_id);

CREATE INDEX idx_trivia_answers_is_correct ON gamification.trivia_answers USING btree (is_correct);

CREATE INDEX idx_trivia_answers_question_id ON gamification.trivia_answers USING btree (question_id);

CREATE INDEX idx_trivia_attempts_attempted_at ON gamification.trivia_attempts USING btree (attempted_at);

CREATE INDEX idx_trivia_attempts_question_id ON gamification.trivia_attempts USING btree (question_id);

CREATE INDEX idx_trivia_attempts_user_id ON gamification.trivia_attempts USING btree (user_id);

CREATE INDEX idx_trivia_questions_active ON gamification.trivia_questions USING btree (active);

CREATE INDEX idx_trivia_questions_difficulty ON gamification.trivia_questions USING btree (difficulty);

CREATE INDEX idx_trivia_questions_plant_species_id ON gamification.trivia_questions USING btree (plant_species_id);

CREATE INDEX idx_user_achievements_achievement_id ON gamification.user_achievements USING btree (achievement_id);

CREATE INDEX idx_user_achievements_earned_at ON gamification.user_achievements USING btree (earned_at);

CREATE INDEX idx_user_achievements_user_id ON gamification.user_achievements USING btree (user_id);

CREATE UNIQUE INDEX plant_discoveries_pkey ON gamification.plant_discoveries USING btree (id);

CREATE UNIQUE INDEX plant_discoveries_scrapbook_id_plant_species_id_key ON gamification.plant_discoveries USING btree (scrapbook_id, plant_species_id);

CREATE UNIQUE INDEX qr_codes_code_token_key ON gamification.qr_codes USING btree (code_token);

CREATE UNIQUE INDEX qr_codes_pkey ON gamification.qr_codes USING btree (id);

CREATE UNIQUE INDEX qr_scans_pkey ON gamification.qr_scans USING btree (id);

CREATE UNIQUE INDEX scrapbooks_pkey ON gamification.scrapbooks USING btree (id);

CREATE UNIQUE INDEX trivia_answers_pkey ON gamification.trivia_answers USING btree (id);

CREATE UNIQUE INDEX trivia_attempts_pkey ON gamification.trivia_attempts USING btree (id);

CREATE UNIQUE INDEX trivia_questions_pkey ON gamification.trivia_questions USING btree (id);

CREATE UNIQUE INDEX user_achievements_pkey ON gamification.user_achievements USING btree (id);

CREATE UNIQUE INDEX user_achievements_user_id_achievement_id_key ON gamification.user_achievements USING btree (user_id, achievement_id);

CREATE INDEX idx_plant_instances_identifier ON inventory.plant_instances USING btree (identifier);

CREATE INDEX idx_plant_instances_plant_species_id ON inventory.plant_instances USING btree (plant_species_id);

CREATE INDEX idx_plant_instances_status ON inventory.plant_instances USING btree (status);

CREATE INDEX idx_plant_instances_storage_location_id ON inventory.plant_instances USING btree (storage_location_id);

CREATE INDEX idx_plant_notes_created_at ON inventory.plant_notes USING btree (created_at);

CREATE INDEX idx_plant_notes_note_type ON inventory.plant_notes USING btree (note_type);

CREATE INDEX idx_plant_notes_plant_instance_id ON inventory.plant_notes USING btree (plant_instance_id);

CREATE INDEX idx_plant_notes_staff_user_id ON inventory.plant_notes USING btree (staff_user_id);

CREATE INDEX idx_plant_species_common_name ON inventory.plant_species USING btree (common_name);

CREATE INDEX idx_plant_species_scientific_name ON inventory.plant_species USING btree (scientific_name);

CREATE INDEX idx_stock_requests_plant_species_id ON inventory.stock_requests USING btree (plant_species_id);

CREATE INDEX idx_stock_requests_priority ON inventory.stock_requests USING btree (priority);

CREATE INDEX idx_stock_requests_requested_by_user_id ON inventory.stock_requests USING btree (requested_by_user_id);

CREATE INDEX idx_stock_requests_status ON inventory.stock_requests USING btree (status);

CREATE INDEX idx_storage_locations_location_type ON inventory.storage_locations USING btree (location_type);

CREATE UNIQUE INDEX plant_instances_pkey ON inventory.plant_instances USING btree (id);

CREATE UNIQUE INDEX plant_notes_pkey ON inventory.plant_notes USING btree (id);

CREATE UNIQUE INDEX plant_species_pkey ON inventory.plant_species USING btree (id);

CREATE UNIQUE INDEX plant_species_scientific_name_key ON inventory.plant_species USING btree (scientific_name);

CREATE UNIQUE INDEX stock_requests_pkey ON inventory.stock_requests USING btree (id);

CREATE UNIQUE INDEX storage_locations_name_key ON inventory.storage_locations USING btree (name);

CREATE UNIQUE INDEX storage_locations_pkey ON inventory.storage_locations USING btree (id);

CREATE UNIQUE INDEX announcements_pkey ON staff.announcements USING btree (id);

CREATE INDEX idx_announcements_created_at ON staff.announcements USING btree (created_at);

CREATE INDEX idx_announcements_created_by_user_id ON staff.announcements USING btree (created_by_user_id);

CREATE INDEX idx_announcements_expires_at ON staff.announcements USING btree (expires_at) WHERE (expires_at IS NOT NULL);

CREATE INDEX idx_announcements_priority ON staff.announcements USING btree (priority);

CREATE INDEX idx_schedules_shift_end ON staff.schedules USING btree (shift_end);

CREATE INDEX idx_schedules_shift_start ON staff.schedules USING btree (shift_start);

CREATE INDEX idx_schedules_user_id ON staff.schedules USING btree (user_id);

CREATE INDEX idx_task_comments_task_id ON staff.task_comments USING btree (task_id);

CREATE INDEX idx_task_comments_user_id ON staff.task_comments USING btree (user_id);

CREATE INDEX idx_tasks_assigned_to_user_id ON staff.tasks USING btree (assigned_to_user_id);

CREATE INDEX idx_tasks_created_by_user_id ON staff.tasks USING btree (created_by_user_id);

CREATE INDEX idx_tasks_due_date ON staff.tasks USING btree (due_date) WHERE (due_date IS NOT NULL);

CREATE INDEX idx_tasks_priority ON staff.tasks USING btree (priority);

CREATE INDEX idx_tasks_status ON staff.tasks USING btree (status);

CREATE UNIQUE INDEX schedules_pkey ON staff.schedules USING btree (id);

CREATE UNIQUE INDEX task_comments_pkey ON staff.task_comments USING btree (id);

CREATE UNIQUE INDEX tasks_pkey ON staff.tasks USING btree (id);

alter table "agent"."conversation_messages" add constraint "conversation_messages_pkey" PRIMARY KEY using index "conversation_messages_pkey";

alter table "agent"."conversations" add constraint "conversations_pkey" PRIMARY KEY using index "conversations_pkey";

alter table "agent"."knowledge_chunks" add constraint "knowledge_chunks_pkey" PRIMARY KEY using index "knowledge_chunks_pkey";

alter table "agent"."knowledge_documents" add constraint "knowledge_documents_pkey" PRIMARY KEY using index "knowledge_documents_pkey";

alter table "agent"."user_memories" add constraint "user_memories_pkey" PRIMARY KEY using index "user_memories_pkey";

alter table "auth0"."roles" add constraint "roles_pkey" PRIMARY KEY using index "roles_pkey";

alter table "auth0"."user_roles" add constraint "user_roles_pkey" PRIMARY KEY using index "user_roles_pkey";

alter table "auth0"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

alter table "dome"."event_registrations" add constraint "event_registrations_pkey" PRIMARY KEY using index "event_registrations_pkey";

alter table "dome"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "dome"."info_pages" add constraint "info_pages_pkey" PRIMARY KEY using index "info_pages_pkey";

alter table "gamification"."achievements" add constraint "achievements_pkey" PRIMARY KEY using index "achievements_pkey";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_pkey" PRIMARY KEY using index "plant_discoveries_pkey";

alter table "gamification"."qr_codes" add constraint "qr_codes_pkey" PRIMARY KEY using index "qr_codes_pkey";

alter table "gamification"."qr_scans" add constraint "qr_scans_pkey" PRIMARY KEY using index "qr_scans_pkey";

alter table "gamification"."scrapbooks" add constraint "scrapbooks_pkey" PRIMARY KEY using index "scrapbooks_pkey";

alter table "gamification"."trivia_answers" add constraint "trivia_answers_pkey" PRIMARY KEY using index "trivia_answers_pkey";

alter table "gamification"."trivia_attempts" add constraint "trivia_attempts_pkey" PRIMARY KEY using index "trivia_attempts_pkey";

alter table "gamification"."trivia_questions" add constraint "trivia_questions_pkey" PRIMARY KEY using index "trivia_questions_pkey";

alter table "gamification"."user_achievements" add constraint "user_achievements_pkey" PRIMARY KEY using index "user_achievements_pkey";

alter table "inventory"."plant_instances" add constraint "plant_instances_pkey" PRIMARY KEY using index "plant_instances_pkey";

alter table "inventory"."plant_notes" add constraint "plant_notes_pkey" PRIMARY KEY using index "plant_notes_pkey";

alter table "inventory"."plant_species" add constraint "plant_species_pkey" PRIMARY KEY using index "plant_species_pkey";

alter table "inventory"."stock_requests" add constraint "stock_requests_pkey" PRIMARY KEY using index "stock_requests_pkey";

alter table "inventory"."storage_locations" add constraint "storage_locations_pkey" PRIMARY KEY using index "storage_locations_pkey";

alter table "staff"."announcements" add constraint "announcements_pkey" PRIMARY KEY using index "announcements_pkey";

alter table "staff"."schedules" add constraint "schedules_pkey" PRIMARY KEY using index "schedules_pkey";

alter table "staff"."task_comments" add constraint "task_comments_pkey" PRIMARY KEY using index "task_comments_pkey";

alter table "staff"."tasks" add constraint "tasks_pkey" PRIMARY KEY using index "tasks_pkey";

alter table "agent"."conversation_messages" add constraint "conversation_messages_conversation_id_fkey" FOREIGN KEY (conversation_id) REFERENCES agent.conversations(id) ON DELETE CASCADE not valid;

alter table "agent"."conversation_messages" validate constraint "conversation_messages_conversation_id_fkey";

alter table "agent"."conversation_messages" add constraint "conversation_messages_sender_type_check" CHECK ((sender_type = ANY (ARRAY['user'::text, 'assistant'::text]))) not valid;

alter table "agent"."conversation_messages" validate constraint "conversation_messages_sender_type_check";

alter table "agent"."conversations" add constraint "conversations_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) not valid;

alter table "agent"."conversations" validate constraint "conversations_plant_species_id_fkey";

alter table "agent"."conversations" add constraint "conversations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE SET NULL not valid;

alter table "agent"."conversations" validate constraint "conversations_user_id_fkey";

alter table "agent"."knowledge_chunks" add constraint "knowledge_chunks_document_id_chunk_index_key" UNIQUE using index "knowledge_chunks_document_id_chunk_index_key";

alter table "agent"."knowledge_chunks" add constraint "knowledge_chunks_document_id_fkey" FOREIGN KEY (document_id) REFERENCES agent.knowledge_documents(id) ON DELETE CASCADE not valid;

alter table "agent"."knowledge_chunks" validate constraint "knowledge_chunks_document_id_fkey";

alter table "agent"."knowledge_documents" add constraint "knowledge_documents_document_type_check" CHECK ((document_type = ANY (ARRAY['care_guide'::text, 'fact_sheet'::text, 'article'::text, 'faq'::text, 'other'::text]))) not valid;

alter table "agent"."knowledge_documents" validate constraint "knowledge_documents_document_type_check";

alter table "agent"."knowledge_documents" add constraint "knowledge_documents_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) not valid;

alter table "agent"."knowledge_documents" validate constraint "knowledge_documents_plant_species_id_fkey";

alter table "agent"."user_memories" add constraint "user_memories_importance_check" CHECK (((importance >= 1) AND (importance <= 10))) not valid;

alter table "agent"."user_memories" validate constraint "user_memories_importance_check";

alter table "agent"."user_memories" add constraint "user_memories_memory_type_check" CHECK ((memory_type = ANY (ARRAY['preference'::text, 'fact'::text, 'interest'::text, 'goal'::text, 'other'::text]))) not valid;

alter table "agent"."user_memories" validate constraint "user_memories_memory_type_check";

alter table "agent"."user_memories" add constraint "user_memories_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "agent"."user_memories" validate constraint "user_memories_user_id_fkey";

alter table "auth0"."roles" add constraint "roles_name_key" UNIQUE using index "roles_name_key";

alter table "auth0"."user_roles" add constraint "user_roles_role_id_fkey" FOREIGN KEY (role_id) REFERENCES auth0.roles(id) ON DELETE CASCADE not valid;

alter table "auth0"."user_roles" validate constraint "user_roles_role_id_fkey";

alter table "auth0"."user_roles" add constraint "user_roles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "auth0"."user_roles" validate constraint "user_roles_user_id_fkey";

alter table "auth0"."users" add constraint "users_auth0_user_id_key" UNIQUE using index "users_auth0_user_id_key";

alter table "auth0"."users" add constraint "users_email_key" UNIQUE using index "users_email_key";

alter table "dome"."event_registrations" add constraint "event_registrations_event_id_fkey" FOREIGN KEY (event_id) REFERENCES dome.events(id) ON DELETE CASCADE not valid;

alter table "dome"."event_registrations" validate constraint "event_registrations_event_id_fkey";

alter table "dome"."event_registrations" add constraint "event_registrations_status_check" CHECK ((status = ANY (ARRAY['registered'::text, 'attended'::text, 'cancelled'::text, 'no_show'::text]))) not valid;

alter table "dome"."event_registrations" validate constraint "event_registrations_status_check";

alter table "dome"."event_registrations" add constraint "event_registrations_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE SET NULL not valid;

alter table "dome"."event_registrations" validate constraint "event_registrations_user_id_fkey";

alter table "dome"."events" add constraint "events_check" CHECK ((end_time > start_time)) not valid;

alter table "dome"."events" validate constraint "events_check";

alter table "dome"."events" add constraint "events_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES auth0.users(id) not valid;

alter table "dome"."events" validate constraint "events_created_by_user_id_fkey";

alter table "dome"."events" add constraint "events_event_type_check" CHECK ((event_type = ANY (ARRAY['tour'::text, 'class'::text, 'exhibition'::text, 'special_event'::text, 'other'::text]))) not valid;

alter table "dome"."events" validate constraint "events_event_type_check";

alter table "dome"."info_pages" add constraint "info_pages_slug_key" UNIQUE using index "info_pages_slug_key";

alter table "gamification"."achievements" add constraint "achievements_name_key" UNIQUE using index "achievements_name_key";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) not valid;

alter table "gamification"."plant_discoveries" validate constraint "plant_discoveries_plant_species_id_fkey";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_scrapbook_id_fkey" FOREIGN KEY (scrapbook_id) REFERENCES gamification.scrapbooks(id) ON DELETE CASCADE not valid;

alter table "gamification"."plant_discoveries" validate constraint "plant_discoveries_scrapbook_id_fkey";

alter table "gamification"."plant_discoveries" add constraint "plant_discoveries_scrapbook_id_plant_species_id_key" UNIQUE using index "plant_discoveries_scrapbook_id_plant_species_id_key";

alter table "gamification"."qr_codes" add constraint "qr_codes_code_token_key" UNIQUE using index "qr_codes_code_token_key";

alter table "gamification"."qr_codes" add constraint "qr_codes_plant_instance_id_fkey" FOREIGN KEY (plant_instance_id) REFERENCES inventory.plant_instances(id) not valid;

alter table "gamification"."qr_codes" validate constraint "qr_codes_plant_instance_id_fkey";

alter table "gamification"."qr_scans" add constraint "qr_scans_qr_code_id_fkey" FOREIGN KEY (qr_code_id) REFERENCES gamification.qr_codes(id) ON DELETE CASCADE not valid;

alter table "gamification"."qr_scans" validate constraint "qr_scans_qr_code_id_fkey";

alter table "gamification"."qr_scans" add constraint "qr_scans_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) not valid;

alter table "gamification"."qr_scans" validate constraint "qr_scans_user_id_fkey";

alter table "gamification"."scrapbooks" add constraint "scrapbooks_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "gamification"."scrapbooks" validate constraint "scrapbooks_user_id_fkey";

alter table "gamification"."trivia_answers" add constraint "trivia_answers_question_id_fkey" FOREIGN KEY (question_id) REFERENCES gamification.trivia_questions(id) ON DELETE CASCADE not valid;

alter table "gamification"."trivia_answers" validate constraint "trivia_answers_question_id_fkey";

alter table "gamification"."trivia_attempts" add constraint "trivia_attempts_question_id_fkey" FOREIGN KEY (question_id) REFERENCES gamification.trivia_questions(id) not valid;

alter table "gamification"."trivia_attempts" validate constraint "trivia_attempts_question_id_fkey";

alter table "gamification"."trivia_attempts" add constraint "trivia_attempts_selected_answer_id_fkey" FOREIGN KEY (selected_answer_id) REFERENCES gamification.trivia_answers(id) not valid;

alter table "gamification"."trivia_attempts" validate constraint "trivia_attempts_selected_answer_id_fkey";

alter table "gamification"."trivia_attempts" add constraint "trivia_attempts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE SET NULL not valid;

alter table "gamification"."trivia_attempts" validate constraint "trivia_attempts_user_id_fkey";

alter table "gamification"."trivia_questions" add constraint "trivia_questions_difficulty_check" CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text]))) not valid;

alter table "gamification"."trivia_questions" validate constraint "trivia_questions_difficulty_check";

alter table "gamification"."trivia_questions" add constraint "trivia_questions_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) not valid;

alter table "gamification"."trivia_questions" validate constraint "trivia_questions_plant_species_id_fkey";

alter table "gamification"."user_achievements" add constraint "user_achievements_achievement_id_fkey" FOREIGN KEY (achievement_id) REFERENCES gamification.achievements(id) ON DELETE CASCADE not valid;

alter table "gamification"."user_achievements" validate constraint "user_achievements_achievement_id_fkey";

alter table "gamification"."user_achievements" add constraint "user_achievements_user_id_achievement_id_key" UNIQUE using index "user_achievements_user_id_achievement_id_key";

alter table "gamification"."user_achievements" add constraint "user_achievements_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "gamification"."user_achievements" validate constraint "user_achievements_user_id_fkey";

alter table "inventory"."plant_instances" add constraint "plant_instances_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) ON DELETE CASCADE not valid;

alter table "inventory"."plant_instances" validate constraint "plant_instances_plant_species_id_fkey";

alter table "inventory"."plant_instances" add constraint "plant_instances_status_check" CHECK ((status = ANY (ARRAY['available'::text, 'reserved'::text, 'sold'::text, 'removed'::text]))) not valid;

alter table "inventory"."plant_instances" validate constraint "plant_instances_status_check";

alter table "inventory"."plant_instances" add constraint "plant_instances_storage_location_id_fkey" FOREIGN KEY (storage_location_id) REFERENCES inventory.storage_locations(id) not valid;

alter table "inventory"."plant_instances" validate constraint "plant_instances_storage_location_id_fkey";

alter table "inventory"."plant_notes" add constraint "plant_notes_note_type_check" CHECK ((note_type = ANY (ARRAY['observation'::text, 'maintenance'::text, 'issue'::text, 'transfer'::text, 'other'::text]))) not valid;

alter table "inventory"."plant_notes" validate constraint "plant_notes_note_type_check";

alter table "inventory"."plant_notes" add constraint "plant_notes_plant_instance_id_fkey" FOREIGN KEY (plant_instance_id) REFERENCES inventory.plant_instances(id) ON DELETE CASCADE not valid;

alter table "inventory"."plant_notes" validate constraint "plant_notes_plant_instance_id_fkey";

alter table "inventory"."plant_notes" add constraint "plant_notes_staff_user_id_fkey" FOREIGN KEY (staff_user_id) REFERENCES auth0.users(id) not valid;

alter table "inventory"."plant_notes" validate constraint "plant_notes_staff_user_id_fkey";

alter table "inventory"."plant_species" add constraint "plant_species_scientific_name_key" UNIQUE using index "plant_species_scientific_name_key";

alter table "inventory"."stock_requests" add constraint "stock_requests_plant_species_id_fkey" FOREIGN KEY (plant_species_id) REFERENCES inventory.plant_species(id) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_plant_species_id_fkey";

alter table "inventory"."stock_requests" add constraint "stock_requests_priority_check" CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]))) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_priority_check";

alter table "inventory"."stock_requests" add constraint "stock_requests_quantity_check" CHECK ((quantity > 0)) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_quantity_check";

alter table "inventory"."stock_requests" add constraint "stock_requests_requested_by_user_id_fkey" FOREIGN KEY (requested_by_user_id) REFERENCES auth0.users(id) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_requested_by_user_id_fkey";

alter table "inventory"."stock_requests" add constraint "stock_requests_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'ordered'::text, 'received'::text, 'rejected'::text]))) not valid;

alter table "inventory"."stock_requests" validate constraint "stock_requests_status_check";

alter table "inventory"."storage_locations" add constraint "storage_locations_location_type_check" CHECK ((location_type = ANY (ARRAY['greenhouse'::text, 'dome'::text, 'storage'::text, 'quarantine'::text, 'other'::text]))) not valid;

alter table "inventory"."storage_locations" validate constraint "storage_locations_location_type_check";

alter table "inventory"."storage_locations" add constraint "storage_locations_name_key" UNIQUE using index "storage_locations_name_key";

alter table "staff"."announcements" add constraint "announcements_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES auth0.users(id) not valid;

alter table "staff"."announcements" validate constraint "announcements_created_by_user_id_fkey";

alter table "staff"."announcements" add constraint "announcements_priority_check" CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]))) not valid;

alter table "staff"."announcements" validate constraint "announcements_priority_check";

alter table "staff"."schedules" add constraint "schedules_check" CHECK ((shift_end > shift_start)) not valid;

alter table "staff"."schedules" validate constraint "schedules_check";

alter table "staff"."schedules" add constraint "schedules_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) ON DELETE CASCADE not valid;

alter table "staff"."schedules" validate constraint "schedules_user_id_fkey";

alter table "staff"."task_comments" add constraint "task_comments_task_id_fkey" FOREIGN KEY (task_id) REFERENCES staff.tasks(id) ON DELETE CASCADE not valid;

alter table "staff"."task_comments" validate constraint "task_comments_task_id_fkey";

alter table "staff"."task_comments" add constraint "task_comments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth0.users(id) not valid;

alter table "staff"."task_comments" validate constraint "task_comments_user_id_fkey";

alter table "staff"."tasks" add constraint "tasks_assigned_to_user_id_fkey" FOREIGN KEY (assigned_to_user_id) REFERENCES auth0.users(id) not valid;

alter table "staff"."tasks" validate constraint "tasks_assigned_to_user_id_fkey";

alter table "staff"."tasks" add constraint "tasks_created_by_user_id_fkey" FOREIGN KEY (created_by_user_id) REFERENCES auth0.users(id) not valid;

alter table "staff"."tasks" validate constraint "tasks_created_by_user_id_fkey";

alter table "staff"."tasks" add constraint "tasks_priority_check" CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text]))) not valid;

alter table "staff"."tasks" validate constraint "tasks_priority_check";

alter table "staff"."tasks" add constraint "tasks_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text]))) not valid;

alter table "staff"."tasks" validate constraint "tasks_status_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION auth0.set_updated_at_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION auth0.upsert_user(p_auth0_user_id text, p_email text, p_display_name text, p_name text, p_given_name text, p_family_name text, p_picture_url text, p_locale text, p_profile_metadata jsonb, p_app_metadata jsonb, p_is_active boolean, p_updated_at timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO auth0.users (
    auth0_user_id,
    email,
    display_name,
    name,
    given_name,
    family_name,
    picture_url,
    locale,
    profile_metadata,
    app_metadata,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    p_auth0_user_id,
    p_email,
    p_display_name,
    p_name,
    p_given_name,
    p_family_name,
    p_picture_url,
    p_locale,
    p_profile_metadata,
    p_app_metadata,
    p_is_active,
    NOW(),
    p_updated_at
  )
  ON CONFLICT (auth0_user_id)  -- assuming this is unique
  DO UPDATE SET
    email            = EXCLUDED.email,
    display_name     = EXCLUDED.display_name,
    name             = EXCLUDED.name,
    given_name       = EXCLUDED.given_name,
    family_name      = EXCLUDED.family_name,
    picture_url      = EXCLUDED.picture_url,
    locale           = EXCLUDED.locale,
    profile_metadata = EXCLUDED.profile_metadata,
    app_metadata     = EXCLUDED.app_metadata,
    is_active        = EXCLUDED.is_active,
    updated_at       = EXCLUDED.updated_at
  ;
END;
$function$
;

CREATE TRIGGER trg_auth0_users_updated_at BEFORE UPDATE ON auth0.users FOR EACH ROW EXECUTE FUNCTION auth0.set_updated_at_timestamp();


