const { Router } = require("express");
const ctrl = require("../controllers/todo.controller");

const router = Router();

router.post("/", ctrl.create);
router.get("/", ctrl.list);
router.get("/:id", ctrl.getById);
router.delete("/:id", ctrl.remove);

module.exports = router;