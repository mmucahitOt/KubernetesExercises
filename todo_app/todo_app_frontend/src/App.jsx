import { useState } from 'react'
import { config } from './config/env'
import { TodoCreate } from './components/TodoCreate'
import { TodoList } from './components/TodoList'
import todoService from './services/todo-service'

function App() {
  const [todos, setTodos] = useState([])

  const createTodo = (todo) => {
    todoService.createTodo({
      text: todo
    }).then(() => {
      getTodoList()
    })
  }

  const getTodoList = () => {
    todoService.getTodoList().then((data) => {
      const todos = data.map(elem => elem.text)
      setTodos(todos)
    })
  }

  useState(() => {
    getTodoList()
  }, [])
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