# todo_app_frontend (React + Vite)

## Brief

- React frontend built with Vite; built assets are copied into `todo_app/public/` during deployment
- Uses environment URLs provided at deploy time to call the backend

## Commands (from this folder)

```bash
# Local dev with HMR
npm run dev

# Build for production
npm run build

# Preview built app locally
npm run preview
```

Notes:

- The deploy script sets `VITE_TODO_API_URL` and `VITE_TODO_BACKEND_API_URL` which the frontend can use to call the APIs.
- The server (`todo_app`) serves the built `dist/` under `/`.
