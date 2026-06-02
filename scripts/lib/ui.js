import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';

export async function ask(question) {
  const rl = createInterface({ input: stdin, output: stdout });
  const a = await rl.question(question);
  rl.close();
  return a.trim();
}

export function say(...lines) {
  console.log(...lines);
}

export function yes(s) {
  return /^(s|si|sí|y|yes|ok|vale|dale)/i.test(s.trim());
}
