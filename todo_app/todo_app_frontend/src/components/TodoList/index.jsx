export const TodoList = ({todos}) => {
  const renderTodoContent = (todo) => {
    // Check if the todo contains HTML tags
    if (todo.includes('<a href=') && todo.includes('</a>')) {
      return (
        <span>
          Read this article. Link: <span dangerouslySetInnerHTML={{ __html: todo }} />
        </span>
      )
    }
    return todo
  }

  return (
    <ul>
      {todos.map((todo, index) => (
        <li key={index}>{renderTodoContent(todo)}</li>
      ))}
    </ul>
  )
}