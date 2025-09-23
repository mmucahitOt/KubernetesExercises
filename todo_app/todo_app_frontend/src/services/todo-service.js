import axios from "axios";
import { config } from "../config/env";

const url = config.backendApiUrl + "/todos";

export const createTodo = async ({ text }) => {
  const response = await axios.post(url, {
    text: text,
  });

  return response?.data;
};

export const getTodoList = async () => {
  const response = await axios.get(url);

  return response?.data;
};

export default {
  createTodo,
  getTodoList,
};
