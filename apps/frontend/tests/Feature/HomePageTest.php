<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Jobs\TestJob;
use App\Mail\TestMail;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class HomePageTest extends TestCase
{
    public function test_home_displays_the_index_page(): void
    {
        $this->get('/')
            ->assertOk()
            ->assertViewIs('home')
            ->assertSeeText('This is the index page');
    }

    public function test_job_endpoint_dispatches_the_demo_job(): void
    {
        Queue::fake();

        $this->get('/start-test-job')->assertOk()->assertContent('OK');

        Queue::assertPushedOnce(TestJob::class);
    }

    public function test_mail_endpoint_sends_the_demo_message(): void
    {
        Mail::fake();

        $this->get('/start-test-mail')->assertOk()->assertContent('OK');

        $mail = Mail::sent(TestMail::class)->sole();
        $mail->assertHasTo('user1@example.com')
            ->assertHasSubject('Test Mail')
            ->assertSeeInHtml('this is test email');
        $this->assertSame([], $mail->attachments());
    }
}
