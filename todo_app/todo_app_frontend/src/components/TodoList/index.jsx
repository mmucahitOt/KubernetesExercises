export const TodoList = ({todos, markAsDone}) => {
  const renderTodoContent = (todo) => {
    const todoText = todo.text || todo;
    if (typeof todoText === 'string' && todoText.includes('<a href=') && todoText.includes('</a>')) {
      return (
        <span>
          Read this article. Link: <span dangerouslySetInnerHTML={{ __html: todoText }} />
        </span>
      )
    }
    return todoText
  }

  return (
    <ul>
      {todos.map((todo, index) => {
        const todoId = todo.id || index;
        const todoText = todo.text || todo;
        const isDone = todo.done || false;
        const isArticle = typeof todoText === 'string' && todoText.includes('<a href=') && todoText.includes('</a>');
        
        return (
          <li key={todoId} style={{ marginBottom: '10px' }}>
            {renderTodoContent(todo)}
            {isArticle && !isDone && (
              <button 
                onClick={() => markAsDone(todoId)}
                style={{ marginLeft: '10px', padding: '5px 10px' }}
              >
                Mark as done
              </button>
            )}
          </li>
        )
      })}
    </ul>
  )
}