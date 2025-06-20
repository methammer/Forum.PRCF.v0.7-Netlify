import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

console.log("Hello from hello-world function!");

serve(async (_req: Request) => {
  console.log("Request received in hello-world");
  return new Response(
    JSON.stringify({ message: "Hello from hello-world function!" }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    }
  );
});
