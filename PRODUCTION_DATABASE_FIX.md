# Production Database Fix for Solid Queue

## Problem
The `solid_queue_recurring_tasks` table (and potentially other Solid Queue tables) don't exist in production because `db:schema:load:queue` is unreliable for single-database setups.

## Research Findings

Based on research from:
- [GitHub Issue #365](https://github.com/rails/solid_queue/issues/365) - `db:prepare` unreliable in production
- [Brian Casel Single Database Guide](https://briancasel.gitbook.io/cheatsheet/rails-1/setup-solid-queue-cable-cache-in-rails-8-to-share-a-single-database)
- [Official Solid Queue Repo](https://github.com/rails/solid_queue)
- [Docker/Heroku Deployment Guide](https://stuff-things.net/2024/01/27/using-solid-queue-in-development-with-docker-and-on-heroku/)

**Key Insight**: For single-database setups (where `queue:` inherits from `primary:`), the recommended approach is to **convert `db/queue_schema.rb` into regular migrations** instead of using the separate schema file.

## Solutions (Choose One)

### Option 1: Convert to Regular Migration (RECOMMENDED)

This is the cleanest long-term solution for single-database setups.

**Step 1: Create migration from queue_schema.rb**

```bash
# Generate a new migration
bin/rails generate migration CreateSolidQueueTables

# Then copy the contents of db/queue_schema.rb into the migration's change method
```

**Step 2: Update bin/docker-entrypoint**

Replace the Solid Queue schema loading section with standard migration:

```bash
# Just use db:migrate (it will handle both primary and queue tables)
./bin/rails db:migrate
```

**Step 3: Remove multi-database config**

Since you're using a single database, you can simplify `config/environments/production.rb`:

```ruby
# Remove this line (not needed for single database):
config.solid_queue.connects_to = { database: { writing: :queue } }
```

**Pros:**
- Standard Rails pattern
- Works reliably in all environments
- Easier to understand for future developers

**Cons:**
- Need to run migration in production
- One-time setup work

---

### Option 2: Manual Schema Load in Entrypoint (QUICK FIX)

Update `bin/docker-entrypoint` to manually load the queue schema using Rails runner.

**Step 1: Update bin/docker-entrypoint**

Replace lines 36-59 with:

```bash
if [ "${RAILS_ENV}" = "production" ]; then
  echo "Ensuring Solid Queue tables exist in production..."

  # Directly load queue_schema.rb using Rails runner
  ./bin/rails runner "
    ActiveRecord::Base.establish_connection(:queue)
    load Rails.root.join('db', 'queue_schema.rb')
    puts 'Solid Queue schema loaded successfully'
  " || echo "Schema already loaded or error occurred"
else
  echo "Loading Solid Queue schema for ${RAILS_ENV}..."
  ./bin/rails db:schema:load:queue
fi
```

**Pros:**
- Quick fix
- No migration needed
- Works immediately

**Cons:**
- Non-standard approach
- May have idempotency issues (running multiple times)

---

### Option 3: Use db:migrate Instead (HYBRID)

Since you're using a single database, just use standard migrations for everything.

**Step 1: Check if queue tables exist as migrations**

```bash
ls db/queue_migrate/
```

If you have queue_migrate directory with migrations, you can:

**Step 2: Update bin/docker-entrypoint**

```bash
# Replace the Solid Queue section with:
if [ "${RAILS_ENV}" = "production" ]; then
  echo "Running migrations (includes queue tables)..."
  ./bin/rails db:migrate
else
  ./bin/rails db:migrate
fi
```

**Pros:**
- Simple, standard Rails pattern
- Works for single database

**Cons:**
- Assumes you have migrations (not just schema.rb)

---

## Immediate Fix for Current Production

**Manual Command (Run once in Render Shell):**

```bash
# Option A: Direct schema load
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails runner "
  ActiveRecord::Base.establish_connection(:queue)
  load Rails.root.join('db', 'queue_schema.rb')
"

# Option B: Use db:schema:load:queue
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:queue

# Then restart services
```

## Recommendation

**For your setup**, I recommend **Option 1 (Convert to Regular Migration)** because:
1. You're using a single PostgreSQL database (not separate queue DB)
2. Standard Rails migrations are more reliable than multi-database schema loading
3. Follows the pattern recommended by the community for single-database setups
4. Future deployments will "just work" with `db:migrate`

Let me know which option you'd like to implement!
