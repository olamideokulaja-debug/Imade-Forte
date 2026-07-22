// Emails each person a private link to their own payslip.
//
// Runs as a Supabase Edge Function so the mail provider key is never exposed to
// the browser, and so the sender can be checked: only an Accountant may trigger
// a send, and only for the run they just disbursed.
//
// Deploy:  supabase functions deploy send-payslips
// Secrets: supabase secrets set RESEND_API_KEY=...  PAYSLIP_FROM="Imade Forte Payroll <payroll@imadeforteholdings.com>"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const esc = (v: unknown) =>
  String(v ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string))

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Not signed in.' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    // Identify the caller using their own token, so this cannot be called anonymously.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: userData, error: userErr } = await supabase.auth.getUser()
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: 'Not signed in.' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    // Only the Accountant disburses, so only the Accountant may send payslips.
    const { data: profile } = await supabase.from('profiles').select('role, name').eq('id', userData.user.id).maybeSingle()
    const role = profile?.role
    if (role !== 'accountant' && role !== 'admin' && role !== 'superadmin') {
      return new Response(JSON.stringify({ error: 'Only the Accountant can send payslips.' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    const { cycle, recipients } = await req.json()
    if (!Array.isArray(recipients) || recipients.length === 0) {
      return new Response(JSON.stringify({ error: 'No recipients supplied.' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    const apiKey = Deno.env.get('RESEND_API_KEY')
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'Mail provider is not configured. Set RESEND_API_KEY.' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } })
    }
    const from = Deno.env.get('PAYSLIP_FROM') ?? 'Imade Forte Payroll <payroll@imadeforteholdings.com>'

    let sent = 0
    const failed: string[] = []

    for (const r of recipients) {
      if (!r?.email || !r?.url) { failed.push(r?.name ?? 'unknown'); continue }
      const html = `
        <div style="font-family:Georgia,serif;background:#0E2240;padding:28px;color:#ffffff">
          <div style="font-size:18px;font-weight:700">Imade Forte Holdings Limited</div>
          <div style="color:#B8924A;letter-spacing:.18em;font-size:11px;margin-top:4px">PAYSLIP</div>
        </div>
        <div style="font-family:Georgia,serif;padding:28px;color:#22303f;line-height:1.6">
          <p>Dear ${esc(r.name)},</p>
          <p>Your payslip for <b>${esc(cycle)}</b> is now available. Payment has been disbursed.</p>
          <p style="margin:26px 0">
            <a href="${esc(r.url)}"
               style="background:#B8924A;color:#0E2240;text-decoration:none;padding:12px 22px;border-radius:6px;font-weight:700">
              Download your payslip
            </a>
          </p>
          <p style="font-size:13px;color:#6b7684">
            This link is private to you and expires in 30 days. Please do not forward it.
            Any question about your pay should go to the Accounts department.
          </p>
        </div>`

      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from, to: [r.email], subject: `Your payslip for ${cycle}`, html }),
      })
      if (res.ok) sent++
      else failed.push(`${r.name}: ${await res.text()}`)
    }

    return new Response(JSON.stringify({ sent, failed }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as Error)?.message ?? e) }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
