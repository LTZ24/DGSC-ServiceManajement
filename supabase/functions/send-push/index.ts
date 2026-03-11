// @ts-nocheck

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { SignJWT, importPKCS8 } from 'npm:jose@5.9.6'

type PushPayload = {
  userId?: string
  topic?: string
  title?: string
  message?: string
  type?: string
  relatedId?: string
}

async function getGoogleAccessToken() {
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? ''
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? ''
  const privateKey = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n')

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('Firebase service account secrets belum lengkap.')
  }

  const key = await importPKCS8(privateKey, 'RS256')
  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key)

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenJson = await tokenResponse.json()
  if (!tokenResponse.ok || !tokenJson.access_token) {
    throw new Error(`Gagal mengambil access token Google: ${JSON.stringify(tokenJson)}`)
  }

  return {
    projectId,
    accessToken: tokenJson.access_token as string,
  }
}

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    const body = (await req.json()) as PushPayload
    const userId = body.userId?.trim() ?? ''
    const topic = body.topic?.trim() ?? ''
    const title = body.title?.trim() ?? 'Notifikasi DGSC'
    const message = body.message?.trim() ?? ''

    if ((!userId && !topic) || !message) {
      return new Response(JSON.stringify({ error: 'userId/topic dan message wajib diisi.' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { projectId, accessToken } = await getGoogleAccessToken()
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            topic: topic || `user_${userId}`,
            notification: {
              title,
              body: message,
            },
            data: {
              type: body.type ?? 'general',
              relatedId: body.relatedId ?? '',
            },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'dgsc_general_notifications',
              },
            },
          },
        }),
      },
    )

    const result = await response.text()
    return new Response(result, {
      status: response.status,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    )
  }
})
