# lsm-ops — Agent Skills manifest

Ad-hoc operational tools for the Loan State Machine service.

<available_skills>
  <skill name="fix-customer-info" path="skills/fix-customer-info/SKILL.md">
    Fix customerNumber and customerName on LSM loans via the internal API.
    Triggers when the user asks to fix customer info, patch customer number/name,
    or correct missing customer data on a loan or batch of loans.
  </skill>
</available_skills>
