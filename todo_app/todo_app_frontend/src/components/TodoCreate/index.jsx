import { useState } from "react"

export const TodoCreate = ({createTodo}) => {
  const [todo, setTodo] = useState()

  const handleChangeTodo = (event) => {
    setTodo(event.target.value)
  }
  const handleCreate = () => {
    createTodo(todo)
  }
  return (
    <div>
      <input value={todo} onChange={handleChangeTodo}/>
      <button onClick={handleCreate}>Create TODO</button>
    </div>
  )
}