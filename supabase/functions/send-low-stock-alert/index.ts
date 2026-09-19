// supabase/functions/send-low-stock-alert/index.ts
//
// SETUP:
// Run these from your terminal — never hardcode secrets in this file.
// supabase secrets set GMAIL_USER=your-gmail-address@gmail.com
// supabase secrets set GMAIL_APP_PASSWORD=your-app-password
// supabase functions deploy send-low-stock-alert
//
// SECURITY NOTE: a previous version of this file had a real Gmail address
// and app password committed here. If you haven't already, revoke that
// app password in your Google Account -> Security -> App Passwords, and
// generate a new one using the command above.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { SmtpClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

serve(async (req) => {
  try {
    const { adminEmail, products, threshold, sentAt } = await req.json();

    const productRows = products
      .map((p: { name: string; stock: number; category: string }) =>
        `- ${p.name} (${p.category}): ${p.stock} units left`
      )
      .join("\n");

    const textBody = `
PartMo — Low Stock Alert
Sent: ${new Date(sentAt).toLocaleString()}

The following ${products.length} product(s) have stock at or below ${threshold} units:

${productRows}

Please log in to the PartMo admin dashboard to restock.

-- PartMo Admin System
    `.trim();

    const htmlBody = `
      <div style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px;">
        <div style="background:#073B63;padding:20px;border-radius:6px 6px 0 0;">
          <h2 style="color:#fff;margin:0;font-size:18px;">⚠️ PartMo — Low Stock Alert</h2>
          <p style="color:#B9D2E3;margin:6px 0 0;font-size:12px;">Sent: ${new Date(sentAt).toLocaleString()}</p>
        </div>
        <div style="background:#F4F7FB;padding:20px;">
          <p style="color:#536372;font-size:13px;">
            The following <strong>${products.length} product(s)</strong> have stock at or below 
            <strong>${threshold} units</strong>. Please restock them soon.
          </p>
          <table style="width:100%;border-collapse:collapse;background:#fff;border-radius:4px;overflow:hidden;">
            <thead>
              <tr style="background:#073B63;">
                <th style="padding:10px 12px;color:#fff;text-align:left;font-size:11px;">Product</th>
                <th style="padding:10px 12px;color:#fff;text-align:left;font-size:11px;">Category</th>
                <th style="padding:10px 12px;color:#fff;text-align:left;font-size:11px;">Stock</th>
              </tr>
            </thead>
            <tbody>
              ${products.map((p: { name: string; stock: number; category: string }) => `
                <tr>
                  <td style="padding:8px 12px;border-bottom:1px solid #eee;">${p.name}</td>
                  <td style="padding:8px 12px;border-bottom:1px solid #eee;">${p.category}</td>
                  <td style="padding:8px 12px;border-bottom:1px solid #eee;color:#E85050;font-weight:bold;">${p.stock} units left</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
          <div style="margin-top:20px;padding:14px;background:#fff3cd;border-radius:4px;border-left:4px solid #FFC233;">
            <p style="margin:0;color:#664d03;font-size:12px;">
              <strong>Action Required:</strong> Log in to the PartMo admin dashboard to update stock levels.
            </p>
          </div>
        </div>
        <div style="background:#eee;padding:12px;text-align:center;">
          <p style="margin:0;color:#9AA6B1;font-size:10px;">PartMo Admin System — Do not reply to this email.</p>
        </div>
      </div>
    `;

    const client = new SmtpClient();

    await client.connectTLS({
      hostname: "smtp.gmail.com",
      port: 465,
      username: Deno.env.get("GMAIL_USER")!,
      password: Deno.env.get("GMAIL_APP_PASSWORD")!,
    });

    await client.send({
      from: `PartMo Alerts <${Deno.env.get("GMAIL_USER")}>`,
      to: adminEmail,
      subject: `⚠️ Low Stock Alert: ${products.length} product(s) need restocking`,
      content: textBody,
      html: htmlBody,
    });

    await client.close();

    return new Response(JSON.stringify({ success: true, count: products.length }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
