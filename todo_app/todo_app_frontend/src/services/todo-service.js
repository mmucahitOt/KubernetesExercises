import axios from "axios";
import { config } from "../config/env";

// Use relative path - works with Ingress routing
// Ingress routes /todos to backend service
// config.backendApiUrl already includes "/todos" or defaults to "/todos"
const url = config.backendApiUrl;

export const createTodo = async ({ text }) => {
  const response = await axios.post(url, {
    text: text,
  });

  return response?.data;
};

export const updateTodo = async ({ id, done }) => {
  const response = await axios.patch(`${url}/${id}`, {
    done: done,
  });

  return response?.data;
};

export const getTodoList = async () => {
  const response = await axios.get(url, {});

  return response?.data;
};

export default {
  createTodo,
  updateTodo,
  getTodoList,
};
