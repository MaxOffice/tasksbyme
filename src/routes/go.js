const express = require('express');

const router = express.Router();

router.get("/go/:taskid", (req, res) => {
    tenantid = process.env.TENANT_ID;
    taskid = req.params.taskid;
    res.redirect(`https://tasks.office.com/${tenantid}/Home/Task/${taskid}`);
});

module.exports = router;