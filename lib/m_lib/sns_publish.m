function sns_publish(sns_arn,message)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Joshua Soderholm, Fugro ROAMES, 2017
%
% WHAT: Publishes message to sns_arn
% INPUTS:
% sns_arn: amazon sns arn (String)
% message: message for sns publish (String)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%run publish command
cmd         = ['export LD_LIBRARY_PATH=/usr/lib; aws sns publish --topic-arn ',sns_arn,' --message "',message,'"'];
[sout,eout] = unix([cmd,' >> tmp/log.sns 2>&1 &']);

