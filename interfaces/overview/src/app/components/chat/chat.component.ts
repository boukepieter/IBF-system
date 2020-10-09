import { Component, OnDestroy } from '@angular/core';
import { Subscription } from 'rxjs';
import { ApiService } from 'src/app/services/api.service';
import { CountryService } from 'src/app/services/country.service';
import { EapActionsService } from 'src/app/services/eap-actions.service';
import { TimelineService } from 'src/app/services/timeline.service';
import { EapAction } from 'src/app/types/eap-action';

@Component({
  selector: 'app-chat',
  templateUrl: './chat.component.html',
  styleUrls: ['./chat.component.scss'],
})
export class ChatComponent implements OnDestroy {
  public triggeredAreas: any[];

  private eapActionSubscription: Subscription;
  private countrySubscription: Subscription;
  private timelineSubscription: Subscription;

  public eapActions: EapAction[];
  public changedActions: EapAction[] = [];
  public submitDisabled = true;

  public leadTime: string;
  public trigger: boolean;

  constructor(
    private countryService: CountryService,
    private timelineService: TimelineService,
    private eapActionsService: EapActionsService,
    private apiService: ApiService,
  ) {
    this.countrySubscription = this.countryService
      .getCountrySubscription()
      .subscribe((country) => {
        this.eapActionsService.loadDistrictsAndActions();
        this.getTrigger();
      });

    this.timelineSubscription = this.timelineService
      .getTimelineSubscription()
      .subscribe((timeline) => {
        this.eapActionsService.loadDistrictsAndActions();
        this.getTrigger();
      });

    this.eapActionSubscription = this.eapActionsService
      .getTriggeredAreas()
      .subscribe((newAreas) => {
        this.triggeredAreas = newAreas;
        this.triggeredAreas.forEach((area) => (area.submitDisabled = true));
      });
  }

  ngOnDestroy() {
    this.eapActionSubscription.unsubscribe();
    this.timelineSubscription.unsubscribe();
    this.countrySubscription.unsubscribe();
  }

  private async getTrigger() {
    const timestep = this.timelineService.state.selectedTimeStepButtonValue;
    this.trigger = await this.timelineService.getTrigger(timestep);
    this.leadTime = timestep.replace('-day', ' days from today');
  }

  public changeAction(pcode: string, action: string, checkbox: boolean) {
    const area = this.triggeredAreas.find((i) => i.pcode === pcode);
    const changedAction = area.eapActions.find((i) => i.action === action);
    changedAction.checked = checkbox;
    if (!this.changedActions.includes(changedAction)) {
      this.changedActions.push(changedAction);
    }
    this.triggeredAreas.find((i) => i.pcode === pcode).submitDisabled = false;
  }

  public submitEapAction(pcode: string) {
    this.triggeredAreas.find((i) => i.pcode === pcode).submitDisabled = true;
    this.changedActions.forEach(async (action) => {
      await this.eapActionsService.checkEapAction(
        action.action,
        this.countryService.selectedCountry.countryCode,
        action.checked,
        action.pcode,
      );
    });
    // this.eapActionsService.loadDistrictsAndActions();
    this.changedActions = [];
  }
}
