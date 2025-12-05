# Travel Outfit Planner (TOP)

> **Academic Project:** Master's degree coursework for "Applications of Software Architecture for Big Data"
> **Author:** Malcolm Bailey (solo project)

A Rails web application that fetches weather forecasts and generates intelligent clothing recommendations for travel itineraries. Demonstrates enterprise software architecture patterns including asynchronous job processing, event-driven workflows, and external API integration.

## Architecture Highlights

**Event-Driven Job Pipeline:**
```
User Creates Trip → ForecastFetcherJob → RecommendationAnalyzerJob → Display Results
                    (weather_fetch queue)   (analysis queue)
```

**Key Technologies:**
- **Framework:** Ruby on Rails 8.1
- **Job Queue:** Solid Queue (database-backed, asynchronous processing)
- **Event Messaging:** Job chaining with ActiveJob (event collaboration pattern)
- **REST API Integration:** Tomorrow.io Weather Forecast API
- **Database:** PostgreSQL (single-database architecture)
- **Testing:** RSpec with API mocking (129 passing tests, 0 failures)
- **Deployment:** Docker with multi-process architecture (web + worker)

**Design Patterns:**
- Service objects for business logic encapsulation
- Background job orchestration for long-running operations
- API response caching and deduplication
- Status state machine for workflow tracking
- Event-driven architecture for loose coupling

## Quick Start

**With Docker (Recommended):**
```bash
docker compose up --build
# Visit http://localhost:3000
```

**Local Development:**
```bash
bin/setup
bin/dev  # Starts Rails server + Tailwind CSS + Solid Queue worker
```

## Testing

```bash
# Run full test suite
docker compose run -e RAILS_ENV=test web bundle exec rspec

# Results: 129 examples, 0 failures
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Ruby 3.4.7 |
| Framework | Rails 8.1 |
| Database | PostgreSQL |
| Job Queue | Solid Queue (database-backed) |
| Styling | Tailwind CSS |
| Testing | RSpec + FactoryBot |
| External API | Tomorrow.io Weather API |
| Deployment | Docker + Render.com |

## Documentation

- `CLAUDE.md` - Quick reference guide
- `docs/IMPLEMENTATION_GUIDE.md` - Step-by-step implementation
- `docs/TESTING_GUIDE.md` - Comprehensive testing patterns
- `docs/RENDER_DEPLOYMENT.md` - Production deployment guide

## Project Status

✅ **MVP Complete** - Full CRUD operations, background processing, comprehensive test coverage

---

**License:** Academic use only
