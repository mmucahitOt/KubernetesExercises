import { useState } from 'react'
import { config } from './config/env'
import { TodoCreate } from './components/TodoCreate'
import { TodoList } from './components/TodoList'

function App() {
  const [todos, setTodos] = useState(["Learn JavaScript", "Learn React", "Build a project"])
  const createTodo = (todo) => {
    setTodos([...todos, todo])
  }
  return (
    <div className="app">
      <h1>The project App</h1>
      <img src={config.apiUrl + "/randomimage"} alt="Random" />
      <TodoCreate createTodo={createTodo} />
      <TodoList todos={todos} />
      <h4>DevOps with Kubernetes 2025</h4>
    </div>
  )
}

export default App