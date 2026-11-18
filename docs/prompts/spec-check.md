# Spec check prompt

Codex gets this prompt once per spec, after the spec is written and before it is cut into tickets. A ticket gets no model review.

```
Read this spec and the project rules. Edit nothing. Do not judge the design
or suggest alternatives.

Answer one question: where would an agent implementing this have to guess?

List at most five gaps, most costly first. For each: the part of the spec,
what is undecided, and the one question Aditya must answer to close it.
Something an agent can find out itself by reading code or docs is not a gap.
If there are none, say "No gaps."
```
