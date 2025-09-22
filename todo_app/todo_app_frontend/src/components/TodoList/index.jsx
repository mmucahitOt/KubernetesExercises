export const TodoList = ({todos}) => {
  return (
    <list>
      {todos.map((todo, index) => <li key={index}>{todo}</li>)}
    </list>
  )
}