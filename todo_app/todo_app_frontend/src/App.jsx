import { useState, useEffect } from 'react'
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

  const markAsDone = (todoId) => {
    todoService.updateTodo({
      id: todoId,
      done: true
    }).then(() => {
      getTodoList()
    })
  }

  const getTodoList = () => {
    todoService.getTodoList().then((data) => {
      if (Array.isArray(data)) {
        setTodos(data)
      } else {
        setTodos([])
      }
    })
  }

  useEffect(() => {
    getTodoList()
  }, [])
  return (
    <div className="app">
      <h1>The project App</h1>
      <img src={config.apiUrl + "/randomimage"} alt="Random" />
      <TodoCreate createTodo={createTodo} />
      <h3>Todo</h3>
      <TodoList todos={todos.filter(todo => todo.done === false)} markAsDone={markAsDone} />
      <h3>Done</h3>
      <TodoList todos={todos.filter(todo => todo.done === true)} markAsDone={markAsDone} />
      <p>
        <a
          href="https://courses.mooc.fi/org/uh-cs/courses/devops-with-kubernetes"
          target="_blank"
          rel="noopener noreferrer"
        >
          DevOps with Kubernetes 2025
        </a>
      </p>
    </div>
  )
}

export default App